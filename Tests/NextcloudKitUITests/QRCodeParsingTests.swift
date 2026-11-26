// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import NextcloudKitUI
import Testing

///
/// Test subject which conforms to ``QRCodeParsing``.
///
struct QRCodeParsingTestSubject: QRCodeParsing {}

///
/// Tests for ``QRCodeParsing``.
///
struct QRCodeParsingTests {
    let testSubject: QRCodeParsingTestSubject

    init() {
        testSubject = QRCodeParsingTestSubject()
    }

    @Test(arguments: [
        ("nc://login/", QRCodeError.implausibleLength),
        ("nope://login/user:test&password:secret&server:http://localhost:8080", .invalidPrefix),
        ("nc://login/password:secret&server:http://localhost:8080", .missingUser),
        ("nc://login/user:&password:secret&server:https://cloud.example.com", .missingUser),
        ("nc://login/user:test&server:http://localhost:8080", .missingPassword),
        ("nc://login/user:test&password:secret", .missingHost)
    ]) func invalidCode(_ code: String, _ error: QRCodeError) async throws {
        #expect(throws: error) {
            try testSubject.parseLogin(code)
        }
    }

    @Test func fieldsInAnyOrder() async throws {
        let credentials = try testSubject.parseLogin("nc://login/server:https://cloud.example.com&password:secret&user:jane")

        #expect(credentials.kind == .login)
        #expect(credentials.user == "jane")
        #expect(credentials.password == "secret")
        #expect(credentials.host.absoluteString == "https://cloud.example.com")
    }

    @Test func onetimeLogin() async throws {
        let credentials = try testSubject.parseLogin("nc://onetime-login/user:jane&password:token&server:https://cloud.example.com")

        #expect(credentials.kind == .onetimeLogin)
        #expect(credentials.password == "token")
    }

    @Test func validCallback() async throws {
        let url = try #require(URL(string: "nc://login/server:https://cloud.example.com/nextcloud&user:jane&password:secret"))
        let credentials = try testSubject.parseLoginCallback(url)

        #expect(credentials.kind == .login)
        #expect(credentials.user == "jane")
        #expect(credentials.password == "secret")
        #expect(credentials.host.absoluteString == "https://cloud.example.com/nextcloud")
    }

    @Test func callbackPlusInUserIsSpace() async throws {
        let url = try #require(URL(string: "nc://login/server:https://cloud.example.com&user:jane+doe&password:secret"))

        #expect(try testSubject.parseLoginCallback(url).user == "jane doe")
    }

    @Test func callbackPercentEncodedValues() async throws {
        let url = try #require(URL(string: "nc://login/server:https://cloud.example.com&user:jane%40example.com&password:se%2Bcret"))
        let credentials = try testSubject.parseLoginCallback(url)

        #expect(credentials.user == "jane@example.com")
        #expect(credentials.password == "se+cret")
    }

    @Test func callbackCustomScheme() async throws {
        let url = try #require(URL(string: "abc://login/server:https://cloud.example.com&user:jane&password:secret"))

        #expect(try testSubject.parseLoginCallback(url, scheme: "abc").user == "jane")

        #expect(throws: QRCodeError.invalidPrefix) {
            try testSubject.parseLoginCallback(url)
        }
    }

    @Test(arguments: [QRCodeError.implausibleLength, .invalidPrefix, .missingHost, .missingPassword, .missingUser]) func localizedDescription(_ error: QRCodeError) async throws {
        let description = try #require(error.errorDescription)
        #expect(description.isEmpty == false)
        #expect(error.localizedDescription == description)
    }
}
