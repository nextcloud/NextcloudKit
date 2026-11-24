// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

#if os(iOS)
import CodeScanner
#endif
import Foundation
import NextcloudKit
@testable import NextcloudKitUI
import Testing

///
/// Tests for ``LoginFlowModel`` which need no Nextcloud server.
///
/// Serialized, because parallel requests through the shared `NextcloudKit` sessions drop each other.
///
@MainActor
@Suite(.serialized)
struct LoginFlowModelTests {
    ///
    /// Records what the model hands to the host app.
    ///
    @MainActor
    final class Recorder {
        var addedAccounts: [(host: URL, name: String, password: String)] = []
        var serverErrors: [(error: NKError, url: URL)] = []
        var isActiveDuringAddAccount: Bool?
        var isAddingAccountDuringAddAccount: Bool?
        var isPresentingCodeScannerDuringAddAccount: Bool?
        var addAccountError: Error?
        weak var model: LoginFlowModel?
    }

    private func makeModel(configuration: LoginFlowConfiguration = LoginFlowConfiguration(), recorder: Recorder) -> LoginFlowModel {
        let model = LoginFlowModel(userAgent: nil, configuration: configuration) { host, name, password in
            recorder.isActiveDuringAddAccount = recorder.model?.isActive
            recorder.isAddingAccountDuringAddAccount = recorder.model?.isAddingAccount
            recorder.isPresentingCodeScannerDuringAddAccount = recorder.model?.isPresentingCodeScanner
            recorder.addedAccounts.append((host, name, password))

            if let error = recorder.addAccountError {
                throw error
            }
        }

        recorder.model = model

        return model
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(10)

        while condition() == false {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for the condition.")
                return
            }

            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func prefillsInitialServerAddress() async throws {
        var configuration = LoginFlowConfiguration()
        configuration.initialServerAddress = "https://cloud.example.com"

        let model = makeModel(configuration: configuration, recorder: Recorder())

        #expect(model.enteredServerAddress == "https://cloud.example.com")
    }

    @Test func startsLoginOnAppearOnceWhenConfigured() async throws {
        var configuration = LoginFlowConfiguration()
        configuration.initialServerAddress = "http://127.0.0.1:1"
        configuration.startsLoginOnAppear = true

        let model = makeModel(configuration: configuration, recorder: Recorder())

        model.startLoginOnAppear()

        #expect(model.isActive)

        // Nothing listens on port 1, so the login ends with an error right away.
        try await waitUntil { model.isPresentingAlert }

        model.dismissAlert()
        model.startLoginOnAppear()

        #expect(model.isActive == false)
    }

    @Test func doesNotStartLoginOnAppearByDefault() async throws {
        var configuration = LoginFlowConfiguration()
        configuration.initialServerAddress = "https://cloud.example.com"

        let model = makeModel(configuration: configuration, recorder: Recorder())

        model.startLoginOnAppear()

        #expect(model.isActive == false)
    }

    @Test func emptyAddressDoesNothing() async throws {
        let model = makeModel(recorder: Recorder())
        model.enteredServerAddress = "   "

        model.logIn()

        #expect(model.isActive == false)
        #expect(model.isPresentingAlert == false)
    }

    @Test func invalidAddressPresentsAlert() async throws {
        let model = makeModel(recorder: Recorder())
        model.enteredServerAddress = "ssh://cloud.example.com"

        model.logIn()

        #expect(model.isActive == false)
        #expect(model.isPresentingAlert)
        #expect(model.errorMessage?.isEmpty == false)
    }

    @Test func loginCodeAddsAccountWhileBusy() async throws {
        let recorder = Recorder()
        let model = makeModel(recorder: recorder)

        model.handleLoginCode("nc://login/user:jane&password:secret&server:https://cloud.example.com")

        try await waitUntil { recorder.addedAccounts.count == 1 && model.isActive == false }

        let account = try #require(recorder.addedAccounts.first)
        #expect(account.host.absoluteString == "https://cloud.example.com")
        #expect(account.name == "jane")
        #expect(account.password == "secret")
        #expect(recorder.isActiveDuringAddAccount == true)
        #expect(recorder.isAddingAccountDuringAddAccount == true)
        #expect(model.isAddingAccount == false)
        #expect(model.isPresentingAlert == false)
    }

    @Test func thrownAddAccountErrorIsPresented() async throws {
        let recorder = Recorder()
        let error = NKError(errorCode: 401)
        recorder.addAccountError = error
        let model = makeModel(recorder: recorder)

        model.handleLoginCode("nc://login/user:jane&password:secret&server:https://cloud.example.com")

        try await waitUntil { model.isPresentingAlert }

        #expect(model.errorMessage == error.localizedGenericMessage)
        #expect(model.isActive == false)
    }

    @Test func addAccountFailureWording() async throws {
        let notFound = NKError(errorCode: 404)
        let invalidResponse = NKError.invalidResponseError

        let notFoundMessage = try await addAccountMessage(for: notFound)
        let invalidResponseMessage = try await addAccountMessage(for: invalidResponse)

        // A 404 means a wrong address, while an unreadable reply may come from a proxy in front of a server that exists.
        #expect(notFoundMessage != notFound.localizedGenericMessage)
        #expect(invalidResponseMessage == invalidResponse.localizedGenericMessage)
    }

    private func addAccountMessage(for error: NKError) async throws -> String? {
        let recorder = Recorder()
        recorder.addAccountError = error
        let model = makeModel(recorder: recorder)

        model.handleLoginCode("nc://login/user:jane&password:secret&server:https://cloud.example.com")

        try await waitUntil { model.isPresentingAlert }

        return model.errorMessage
    }

    @Test func loginCodeUsesConfiguredScheme() async throws {
        let recorder = Recorder()
        var configuration = LoginFlowConfiguration()
        configuration.loginURLScheme = "abc"
        let model = makeModel(configuration: configuration, recorder: recorder)

        model.handleLoginCode("nc://login/user:jane&password:secret&server:https://cloud.example.com")

        #expect(model.isPresentingAlert)
        #expect(model.errorMessage == QRCodeError.invalidPrefix.localizedDescription)

        model.handleLoginCode("abc://login/user:jane&password:secret&server:https://cloud.example.com")

        try await waitUntil { recorder.addedAccounts.count == 1 }
    }

    @Test func cancelResetsState() async throws {
        let model = makeModel(recorder: Recorder())
        model.isActive = true
        model.isPresentingLoginPage = true

        model.cancel()

        #expect(model.isActive == false)
        #expect(model.isPresentingLoginPage == false)
    }

    @Test func serverErrorWithoutHandlerIsPresented() async throws {
        let model = makeModel(recorder: Recorder())

        // Nothing listens on port 1, so the connection is refused right away.
        model.enteredServerAddress = "http://127.0.0.1:1"
        model.logIn()

        #expect(model.enteredServerAddress == "http://127.0.0.1:1/")
        #expect(model.isActive)

        try await waitUntil { model.isPresentingAlert }

        #expect(model.isActive == false)
    }

    @Test func serverErrorHandlerCanRetryAndCancel() async throws {
        let recorder = Recorder()
        var configuration = LoginFlowConfiguration()

        configuration.onServerError = { error, url in
            recorder.serverErrors.append((error, url))

            if recorder.serverErrors.count == 1 {
                return .retry(URL(string: "http://127.0.0.1:2/")!) // swiftlint:disable:this force_unwrapping
            }

            return .cancel
        }

        let model = makeModel(configuration: configuration, recorder: recorder)
        model.enteredServerAddress = "127.0.0.1:1"
        model.logIn()

        try await waitUntil { recorder.serverErrors.count == 2 && model.isActive == false }

        #expect(recorder.serverErrors.map(\.url.absoluteString) == ["https://127.0.0.1:1/", "http://127.0.0.1:2/"])
        #expect(model.enteredServerAddress == "http://127.0.0.1:2/")
        #expect(model.isPresentingAlert == false)
    }

    @Test func scannedCodeKeepsScannerOpenUntilAccountIsAdded() async throws {
        let recorder = Recorder()
        let model = makeModel(recorder: recorder)

        model.presentCodeScanner()
        model.handleLoginCode("nc://login/user:jane&password:secret&server:https://cloud.example.com")

        try await waitUntil { recorder.addedAccounts.count == 1 && model.isActive == false }

        #expect(recorder.isPresentingCodeScannerDuringAddAccount == true)
        #expect(model.isPresentingCodeScanner == false)
        #expect(model.isPresentingAlert == false)
    }

    @Test func invalidScannedCodeShowsErrorAndKeepsScanning() async throws {
        let model = makeModel(recorder: Recorder())

        model.presentCodeScanner()
        model.handleLoginCode("https://cloud.example.com")

        #expect(model.isPresentingAlert)
        #expect(model.isPresentingCodeScanner)

        model.dismissAlert()

        #expect(model.isPresentingAlert == false)
        #expect(model.errorMessage == nil)
        #expect(model.isPresentingCodeScanner)
    }

    @Test func failedLoginFromScannedCodeShowsErrorInScanner() async throws {
        let recorder = Recorder()
        recorder.addAccountError = NKError(errorCode: 401)
        let model = makeModel(recorder: recorder)

        model.presentCodeScanner()
        model.handleLoginCode("nc://login/user:jane&password:secret&server:https://cloud.example.com")

        try await waitUntil { model.isPresentingAlert }

        #expect(model.isPresentingCodeScanner)
        #expect(model.isActive == false)

        model.dismissAlert()

        #expect(model.isPresentingCodeScanner)
    }

    #if os(iOS)
    @Test func cameraFailureClosesScannerWithAlert() async throws {
        let model = makeModel(recorder: Recorder())

        model.presentCodeScanner()
        model.handleQRCodeScan(.failure(.permissionDenied))

        #expect(model.isPresentingAlert)
        #expect(model.alertAction == .openSettings)

        model.dismissAlert()

        #expect(model.isPresentingCodeScanner == false)
    }
    #endif

    @Test func cancelWhileRecoveringStopsTheLogin() async throws {
        let recorder = Recorder()
        var configuration = LoginFlowConfiguration()

        configuration.onServerError = { error, url in
            recorder.serverErrors.append((error, url))
            recorder.model?.cancel()

            return .retry(URL(string: "http://127.0.0.1:2/")!) // swiftlint:disable:this force_unwrapping
        }

        let model = makeModel(configuration: configuration, recorder: recorder)
        model.enteredServerAddress = "127.0.0.1:1"
        model.logIn()

        try await waitUntil { recorder.serverErrors.count == 1 && model.isActive == false }
        try await Task.sleep(for: .milliseconds(200))

        #expect(recorder.serverErrors.count == 1)
        #expect(model.enteredServerAddress == "https://127.0.0.1:1/")
        #expect(model.isActive == false)
        #expect(model.isPresentingAlert == false)
    }
}
