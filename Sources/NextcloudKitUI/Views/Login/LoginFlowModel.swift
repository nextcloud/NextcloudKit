// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import AuthenticationServices
#if os(iOS)
import CodeScanner
#endif
import NextcloudKit
import SwiftUI

///
/// Drives the Login Flow v2 for ``ServerAddressView``.
///
/// The flow is identical across all consuming apps, so it lives in the package: check the server
/// status, request the login flow, present its web page, and poll until the server grants an app
/// password. The consumer only provides ``AddAccountHandler`` to persist the resulting credentials.
///
@MainActor
@Observable
final class LoginFlowModel: QRCodeParsing, URLSanitizing {
    ///
    /// An extra action offered by the error alert.
    ///
    enum AlertAction {
        case openSettings
    }

    private let userAgent: String?
    private let configuration: LoginFlowConfiguration
    private let addAccount: AddAccountHandler

    init(userAgent: String?, configuration: LoginFlowConfiguration = LoginFlowConfiguration(), addAccount: @escaping AddAccountHandler) {
        self.userAgent = userAgent
        self.configuration = configuration
        self.addAccount = addAccount
        self.enteredServerAddress = configuration.initialServerAddress ?? ""
    }

    // MARK: - State observed by the view

    /// The unsanitized user input.
    var enteredServerAddress: String

    /// Message to display in case of error.
    var errorMessage: String?

    /// Extra action for the error alert.
    var alertAction: AlertAction?

    /// Whether an activity currently requires disabling the user interface.
    var isActive = false

    /// State toggle for presenting the error alert.
    var isPresentingAlert = false

    /// State toggle for presenting the login page in the system browser.
    var isPresentingLoginPage = false

    /// The login address acquired from the server through the login flow API.
    var loginAddress: URL?

    private var startTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    // MARK: - Login flow

    ///
    /// Sanitize the entered server address and start the login flow.
    ///
    func logIn() {
        guard enteredServerAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }

        guard let sanitizedServerAddress = sanitize(enteredServerAddress, upgradingInsecureHTTP: configuration.upgradesInsecureHTTP) else {
            present(error: String(localized: "The entered server address is invalid.", bundle: .module, comment: "This is an error message."))
            return
        }

        enteredServerAddress = sanitizedServerAddress.absoluteString
        start(serverURL: sanitizedServerAddress)
    }

    ///
    /// Check the server, request the login flow, present its web page and begin polling.
    ///
    func start(serverURL: URL) {
        startTask?.cancel()
        pollingTask?.cancel()
        pollingTask = nil
        isActive = true

        startTask = Task {
            do {
                let options = NKRequestOptions(customUserAgent: userAgent)

                let (_, statusResult) = await NextcloudKit.shared.getServerStatusAsync(serverUrl: serverURL.absoluteString, options: options)

                if case .failure(let error) = statusResult {
                    throw error
                }

                let (endpoint, login, token) = try await NextcloudKit.shared.getLoginFlowV2(serverUrl: serverURL.absoluteString, options: options)

                guard Task.isCancelled == false else { return }

                startPolling(token: token, endpoint: endpoint)

                loginAddress = login
                isPresentingLoginPage = true
            } catch {
                guard Task.isCancelled == false else { return }

                await recover(from: error, serverURL: serverURL)
            }
        }
    }

    private func recover(from error: Error, serverURL: URL) async {
        let nkError = error as? NKError ?? NKError(error: error)

        guard let onServerError = configuration.onServerError else {
            endLogin(nkError)
            return
        }

        nkLog(error: "Login server check failed: \(nkError.logDescription)")

        switch await onServerError(nkError, serverURL) {
        case .retry(let url):
            enteredServerAddress = url.absoluteString
            start(serverURL: url)
        case .cancel:
            cancel()
        case .presentError:
            endLogin(nkError)
        }
    }

    private func startPolling(token: String, endpoint: URL) {
        let deadline = ContinuousClock.now + configuration.pollingTimeout

        pollingTask = Task { [weak self] in
            guard let self else { return }

            let options = NKRequestOptions(customUserAgent: self.userAgent)

            while Task.isCancelled == false {
                guard ContinuousClock.now < deadline else {
                    self.cancel()
                    self.present(error: String(localized: "The login timed out. Please try again.", bundle: .module, comment: "Error message when the user did not finish the login in the browser in time."))
                    return
                }

                let poll = await NextcloudKit.shared.getLoginFlowV2PollAsync(token: token, endpoint: endpoint.absoluteString, options: options)

                guard Task.isCancelled == false else { return }

                if poll.error == .success,
                   let server = poll.server, let host = URL(string: server),
                   let loginName = poll.loginName,
                   let appPassword = poll.appPassword {
                    self.complete(host: host, name: loginName, password: appPassword)
                    return
                }

                // HTTP 404 means the flow is still pending, as do network blips while the user is in the browser.
                let isPending = poll.error == .success || poll.responseData?.response?.statusCode == 404 || LoginPollingPolicy.isTransient(poll.error)

                if isPending == false {
                    self.endLogin(poll.error)
                    return
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func presentLoginPage(_ url: URL, using session: WebAuthenticationSession) async {
        do {
            let callbackURL = try await session.authenticate(using: url, callbackURLScheme: configuration.loginURLScheme, preferredBrowserSession: .ephemeral)

            // A login page that redirects to the callback URL hands over the credentials directly. Otherwise polling continues.
            guard isPresentingLoginPage,
                  let credentials = try? LoginCallbackParser.parse(callbackURL, scheme: configuration.loginURLScheme) else {
                return
            }

            pollingTask?.cancel()
            complete(host: credentials.host, name: credentials.user, password: credentials.password)
        } catch {
            // Already handled when the login completed or was cancelled.
            guard isPresentingLoginPage else { return }

            if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                cancel()
            } else {
                endLogin(error)
            }
        }
    }

    ///
    /// Hand the credentials to the host. The view stays busy until the host has added the account.
    ///
    private func complete(host: URL, name: String, password: String) {
        pollingTask = nil
        isPresentingLoginPage = false
        isActive = true

        // Not a child of the polling or presentation task, which end when the login page closes.
        Task {
            do {
                try await addAccount(host, name, password)
            } catch {
                nkLog(error: "Adding the account failed: \(error)")
                present(error: (error as? NKError)?.localizedGenericMessage ?? error.localizedDescription)
            }

            isActive = false
        }
    }

    ///
    /// Stop the login. Called when the login page is closed, regardless of the reason.
    ///
    func cancel() {
        startTask?.cancel()
        startTask = nil
        pollingTask?.cancel()
        pollingTask = nil
        isActive = false
        isPresentingLoginPage = false
    }

    private func endLogin(_ error: Error?) {
        cancel()

        if let error {
            let nkError = error as? NKError ?? NKError(error: error)

            nkLog(error: "Login failed: \(nkError.logDescription)")
            present(error: message(for: nkError))
        }
    }

    ///
    /// A 404 or an unreadable response during login means there is no Nextcloud instance at the entered address.
    ///
    private func message(for error: NKError) -> String {
        let isInstanceNotFound = error.kind == .notFound || error.kind == .invalidResponse

        if isInstanceNotFound {
            return String(localized: "No server was found at this address.", bundle: .module, comment: "Login error message when the entered address does not point to a Nextcloud server.")
        }

        return error.localizedGenericMessage
    }

    private func present(error: String?, action: AlertAction? = nil) {
        errorMessage = error
        alertAction = action
        isPresentingAlert = true
    }

    // MARK: - QR code

    #if os(iOS)
    func handleQRCodeScan(_ result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            handleLoginCode(result.string)
        case .failure(.permissionDenied):
            present(error: String(localized: "Camera access is required to scan QR codes. Allow it in Settings.", bundle: .module, comment: "Error message when the app may not use the camera to scan a login QR code."), action: .openSettings)
        case .failure:
            present(error: String(localized: "The camera is not available.", bundle: .module, comment: "Error message when the camera cannot be used to scan a login QR code."))
        }
    }
    #endif

    func handleLoginCode(_ code: String) {
        do {
            let credentials = try parseLogin(code, scheme: configuration.loginURLScheme)

            switch credentials.kind {
            case .login:
                complete(host: credentials.host, name: credentials.user, password: credentials.password)
            case .onetimeLogin:
                exchangeOnetimeToken(credentials)
            }
        } catch {
            present(error: error.localizedDescription)
        }
    }

    private func exchangeOnetimeToken(_ credentials: LoginCredentials) {
        isActive = true

        Task {
            let result = await NextcloudKit.shared.getAppPasswordOnetimeAsync(url: credentials.host.absoluteString, user: credentials.user, onetimeToken: credentials.password, userAgent: userAgent)

            if result.error == .success, let token = result.token {
                complete(host: credentials.host, name: credentials.user, password: token)
            } else {
                isActive = false
                nkLog(error: "One-time login failed: \(result.error.logDescription)")
                present(error: message(for: result.error))
            }
        }
    }

    // MARK: - Shared accounts

    func selectSharedAccount(_ account: SharedAccount) {
        enteredServerAddress = account.host.absoluteString
        // Username prefill on the login URL is disabled until https://github.com/nextcloud/server/issues/59874 is resolved.
        logIn()
    }
}
