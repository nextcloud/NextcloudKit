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

    @Test func emptyCode() async throws {
        #expect(throws: QRCodeError.implausibleLength) {
            try testSubject.parse("")
        }
    }

    @Test func invalidPrefix() async throws {
        #expect(throws: QRCodeError.invalidPrefix) {
            try testSubject.parse("nope://login/&user:test&password:secret&server:http://localhost:8080")
        }
    }

    @Test func missingUser() async throws {
        #expect(throws: QRCodeError.missingUser) {
            try testSubject.parse("nc://login/&password:secret&server:http://localhost:8080")
        }
    }

    @Test func missingPassword() async throws {
        #expect(throws: QRCodeError.missingPassword) {
            try testSubject.parse("nc://login/&user:test&server:http://localhost:8080")
        }
    }

    @Test func missingHost() async throws {
        #expect(throws: QRCodeError.missingHost) {
            try testSubject.parse("nc://login/&user:test&password:secret")
        }
    }

    @Test func validCode() async throws {
        #expect(throws: Never.self) {
            try testSubject.parse("nc://login/&user:test&password:secret&server:http://localhost:8080")
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

    @Test func customScheme() async throws {
        let code = "abc://login/user:jane&password:secret&server:https://cloud.example.com"

        #expect(try testSubject.parseLogin(code, scheme: "abc").user == "jane")

        #expect(throws: QRCodeError.invalidPrefix) {
            try testSubject.parseLogin(code)
        }
    }

    @Test func emptyValues() async throws {
        #expect(throws: QRCodeError.missingUser) {
            try testSubject.parseLogin("nc://login/user:&password:secret&server:https://cloud.example.com")
        }
    }

    @Test(arguments: [QRCodeError.implausibleLength, .invalidPrefix, .missingHost, .missingPassword, .missingUser]) func localizedDescription(_ error: QRCodeError) async throws {
        let description = try #require(error.errorDescription)
        #expect(description.isEmpty == false)
        #expect(error.localizedDescription == description)
    }
}
