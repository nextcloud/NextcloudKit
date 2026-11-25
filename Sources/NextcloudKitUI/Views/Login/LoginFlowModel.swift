// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import AuthenticationServices
import AVFoundation
import CodeScanner
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

    /// Whether the account is being added, after which the login can no longer be cancelled.
    var isAddingAccount = false

    /// State toggle for presenting the error alert.
    var isPresentingAlert = false

    /// State toggle for presenting the login page in the system browser.
    var isPresentingLoginPage = false

    /// State toggle for presenting the QR code scanner, which stays open while a scanned code logs in.
    var isPresentingCodeScanner = false

    /// An error of the QR code scanner, shown by the login view once the scanner has closed.
    private var codeScannerError: (message: String?, action: AlertAction?)?

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
            let options = NKRequestOptions(customUserAgent: userAgent)

            let (_, statusResult) = await NextcloudKit.shared.getServerStatusAsync(serverUrl: serverURL.absoluteString, options: options)

            guard Task.isCancelled == false else { return }

            if case .failure(let error) = statusResult {
                await recover(from: error, serverURL: serverURL)
                return
            }

            do {
                let (endpoint, login, token) = try await NextcloudKit.shared.getLoginFlowV2(serverUrl: serverURL.absoluteString, options: options)

                guard Task.isCancelled == false else { return }

                startPolling(token: token, endpoint: endpoint)

                loginAddress = login
                isPresentingLoginPage = true
            } catch {
                guard Task.isCancelled == false else { return }

                endLogin(error)
            }
        }
    }

    private func recover(from error: NKError, serverURL: URL) async {
        guard let onServerError = configuration.onServerError else {
            endLogin(error)
            return
        }

        nkLog(error: "Login server check failed: \(error.logDescription)")

        let recovery = await onServerError(error, serverURL)

        // The user may have cancelled while the host was asking how to recover.
        guard Task.isCancelled == false else { return }

        switch recovery {
        case .retry(let url):
            enteredServerAddress = url.absoluteString
            start(serverURL: url)
        case .cancel:
            cancel()
        case .presentError:
            endLogin(error)
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
    /// - Parameter restartsLoginIfUnauthorized: Start the login for the server when it refuses the credentials.
    ///
    private func complete(host: URL, name: String, password: String, restartsLoginIfUnauthorized: Bool = false) {
        pollingTask = nil
        isPresentingLoginPage = false
        isActive = true
        isAddingAccount = true

        // Not a child of the polling or presentation task, which end when the login page closes.
        Task {
            do {
                try await addAccount(host, name, password)
                isPresentingCodeScanner = false
            } catch let error as NKError where restartsLoginIfUnauthorized && error.kind == .unauthorized {
                nkLog(error: "The server refused the credentials, starting the login: \(error.logDescription)")

                isAddingAccount = false
                isActive = false
                enteredServerAddress = host.absoluteString
                logIn()
                return
            } catch {
                nkLog(error: "Adding the account failed: \(error)")
                present(error: (error as? NKError).map { message(for: $0, whileAddingAccount: true) } ?? error.localizedDescription)
            }

            isAddingAccount = false
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
    /// While adding the account an unreadable response can come from a proxy in front of the server, so only a 404 counts.
    ///
    private func message(for error: NKError, whileAddingAccount: Bool = false) -> String {
        let isInstanceNotFound = error.kind == .notFound || (error.kind == .invalidResponse && !whileAddingAccount)

        if isInstanceNotFound {
            return String(localized: "No server was found at this address.", bundle: .module, comment: "Login error message when the entered address does not point to a Nextcloud server.")
        }

        return error.localizedGenericMessage
    }

    private func present(error: String?, action: AlertAction? = nil) {
        // The scanner closes first; the user opens it again to scan another code.
        if isPresentingCodeScanner {
            codeScannerError = (error, action)
            isPresentingCodeScanner = false
            return
        }

        errorMessage = error
        alertAction = action
        isPresentingAlert = true
    }

    func dismissAlert() {
        errorMessage = nil
        alertAction = nil
        isPresentingAlert = false
    }

    // MARK: - QR code

    func presentCodeScanner() {
        codeScannerError = nil

        #if !targetEnvironment(simulator)
        // The scanner reports neither of these, and a denial only while it is still sliding in.
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            present(error: Self.cameraAccessMessage, action: .openSettings)
            return
        default:
            break
        }

        guard AVCaptureDevice.default(for: .video) != nil else {
            present(error: Self.cameraUnavailableMessage)
            return
        }
        #endif

        isPresentingCodeScanner = true
    }

    ///
    /// Show the error the scanner closed with.
    ///
    func codeScannerDidClose() {
        guard let codeScannerError else { return }

        self.codeScannerError = nil
        present(error: codeScannerError.message, action: codeScannerError.action)
    }

    func handleQRCodeScan(_ result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            handleLoginCode(result.string)
        case .failure(.permissionDenied):
            present(error: Self.cameraAccessMessage, action: .openSettings)
        case .failure:
            present(error: Self.cameraUnavailableMessage)
        }
    }

    private static var cameraAccessMessage: String {
        String(localized: "Camera access is required to scan QR codes. Allow it in Settings.", bundle: .module, comment: "Error message when the app may not use the camera to scan a login QR code.")
    }

    private static var cameraUnavailableMessage: String {
        String(localized: "The camera is not available.", bundle: .module, comment: "Error message when the camera cannot be used to scan a login QR code.")
    }

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
        isAddingAccount = true

        Task {
            let result = await NextcloudKit.shared.getAppPasswordOnetimeAsync(url: credentials.host.absoluteString, user: credentials.user, onetimeToken: credentials.password, userAgent: userAgent)

            if result.error == .success, let token = result.token {
                complete(host: credentials.host, name: credentials.user, password: token)
            } else {
                isAddingAccount = false
                isActive = false
                nkLog(error: "One-time login failed: \(result.error.logDescription)")
                present(error: message(for: result.error))
            }
        }
    }

    // MARK: - Provider sign-up

    /// The provider sign-up page while it is open.
    var providerSignUp: ProviderSignUpModel?

    /// The login callback URL the sign-up ended on, handled once its page has closed.
    private var providerSignUpCallbackURL: URL?

    func presentProviderSignUp(_ url: URL) {
        providerSignUpCallbackURL = nil
        providerSignUp = ProviderSignUpModel(url: url, callbackScheme: configuration.loginURLScheme, userAgent: userAgent) { [weak self] callbackURL in
            self?.finishProviderSignUp(callbackURL: callbackURL)
        }
    }

    func finishProviderSignUp(callbackURL: URL) {
        providerSignUpCallbackURL = callbackURL
        providerSignUp = nil
    }

    ///
    /// Add the account the sign-up ended on, once its page has closed.
    ///
    func providerSignUpDidClose() {
        guard let callbackURL = providerSignUpCallbackURL else { return }

        providerSignUpCallbackURL = nil

        do {
            let credentials = try LoginCallbackParser.parse(callbackURL, scheme: configuration.loginURLScheme)

            // Providers may hand over a session token, which servers refuse, so the user logs in to the new account instead.
            complete(host: credentials.host, name: credentials.user, password: credentials.password, restartsLoginIfUnauthorized: true)
        } catch {
            present(error: error.localizedDescription)
        }
    }

    // MARK: - Shared accounts

    func selectSharedAccount(_ account: SharedAccount) {
        enteredServerAddress = account.host.absoluteString
        // Username prefill on the login URL is disabled until https://github.com/nextcloud/server/issues/59874 is resolved.
        logIn()
    }
}
