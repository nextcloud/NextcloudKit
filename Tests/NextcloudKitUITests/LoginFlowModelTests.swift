// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
@testable import NextcloudKitUI
import Testing

///
/// Tests for ``LoginFlowModel`` which need no Nextcloud server.
///
@MainActor
struct LoginFlowModelTests {
    ///
    /// Records what the model hands to the host app.
    ///
    @MainActor
    final class Recorder {
        var addedAccounts: [(host: URL, name: String, password: String)] = []
        var serverErrors: [(error: NKError, url: URL)] = []
        var isActiveDuringAddAccount: Bool?
        var addAccountError: Error?
        weak var model: LoginFlowModel?
    }

    private func makeModel(configuration: LoginFlowConfiguration = LoginFlowConfiguration(), recorder: Recorder) -> LoginFlowModel {
        let model = LoginFlowModel(userAgent: nil, configuration: configuration) { host, name, password in
            recorder.isActiveDuringAddAccount = recorder.model?.isActive
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
}
