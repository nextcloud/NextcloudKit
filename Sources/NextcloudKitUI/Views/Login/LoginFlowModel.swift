// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

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
    private let userAgent: String?
    private let addAccount: AddAccountHandler

    init(userAgent: String?, addAccount: @escaping AddAccountHandler) {
        self.userAgent = userAgent
        self.addAccount = addAccount
    }

    // MARK: - State observed by the view

    /// The unsanitized user input.
    var enteredServerAddress = ""

    /// Message to display in case of error.
    var errorMessage: String?

    /// Whether an activity currently requires disabling the user interface.
    var isActive = false

    /// State toggle for presenting the error alert.
    var isPresentingAlert = false

    /// State toggle for presenting the web view.
    var isPresentingWebView = false

    /// The login address acquired from the server through the login flow API.
    var loginAddress: URL?

    private var pollingTask: Task<Void, Never>?

    // MARK: - Login flow

    ///
    /// Sanitize the entered server address and start the login flow.
    ///
    func logIn() {
        guard enteredServerAddress.trimmingCharacters(in: .whitespaces).isEmpty == false else {
            return
        }

        guard let sanitizedServerAddress = sanitize(enteredServerAddress) else {
            present(error: String(localized: "The entered server address is invalid.", comment: "This is an error message."))
            return
        }

        start(serverURL: sanitizedServerAddress)
    }

    ///
    /// Check the server, request the login flow, present its web page and begin polling.
    ///
    func start(serverURL: URL) {
        isActive = true

        Task {
            do {
                let options = NKRequestOptions(customUserAgent: userAgent)

                let (_, statusResult) = await NextcloudKit.shared.getServerStatusAsync(serverUrl: serverURL.absoluteString, options: options)

                if case .failure(let error) = statusResult {
                    throw error
                }

                let (endpoint, login, token) = try await NextcloudKit.shared.getLoginFlowV2(serverUrl: serverURL.absoluteString, options: options)

                startPolling(token: token, endpoint: endpoint)

                loginAddress = login
                isPresentingWebView = true
            } catch {
                endLogin(error)
            }
        }
    }

    private func startPolling(token: String, endpoint: URL) {
        pollingTask?.cancel()

        pollingTask = Task { [weak self] in
            guard let self else { return }

            let options = NKRequestOptions(customUserAgent: self.userAgent)

            while Task.isCancelled == false {
                let poll = await NextcloudKit.shared.getLoginFlowV2PollAsync(token: token, endpoint: endpoint.absoluteString, options: options)

                if poll.error == .success,
                   let server = poll.server, let host = URL(string: server),
                   let loginName = poll.loginName,
                   let appPassword = poll.appPassword {
                    self.complete(host: host, name: loginName, password: appPassword)
                    return
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func complete(host: URL, name: String, password: String) {
        pollingTask = nil
        isActive = false
        isPresentingWebView = false
        addAccount(host, name, password)
    }

    ///
    /// Stop polling. Called when the web view is dismissed, regardless of the reason.
    ///
    func cancel() {
        pollingTask?.cancel()
        pollingTask = nil
        isActive = false
        isPresentingWebView = false
    }

    private func endLogin(_ error: Error?) {
        cancel()

        if let error {
            let message = (error as? NKError)?.errorDescription ?? error.localizedDescription
            present(error: message)
        }
    }

    private func present(error: String?) {
        errorMessage = error
        isPresentingAlert = true
    }

    // MARK: - QR code

    #if os(iOS)
    func handleQRCodeScan(_ result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            handleLoginCode(result.string)
        case .failure(let error):
            present(error: error.localizedDescription)
        }
    }
    #endif

    func handleLoginCode(_ code: String) {
        do {
            let credentials = try parseLogin(code)

            switch credentials.kind {
            case .login:
                addAccount(credentials.host, credentials.user, credentials.password)
            case .onetimeLogin:
                exchangeOnetimeToken(credentials)
            }
        } catch {
            present(error: error.localizedDescription)
        }
    }

    private func exchangeOnetimeToken(_ credentials: ParsedLoginCredentials) {
        isActive = true

        Task {
            let result = await NextcloudKit.shared.getAppPasswordOnetimeAsync(url: credentials.host.absoluteString, user: credentials.user, onetimeToken: credentials.password, userAgent: userAgent)

            isActive = false

            if result.error == .success, let token = result.token {
                addAccount(credentials.host, credentials.user, token)
            } else {
                present(error: result.error.errorDescription)
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
