// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import NextcloudKitUI
import Testing

///
/// Tests for ``LoginCallbackParser``.
///
struct LoginCallbackParserTests {
    @Test func validCallback() async throws {
        let url = try #require(URL(string: "nc://login/server:https://cloud.example.com&user:jane&password:secret"))
        let credentials = try LoginCallbackParser.parse(url)

        #expect(credentials.kind == .login)
        #expect(credentials.user == "jane")
        #expect(credentials.password == "secret")
        #expect(credentials.host.absoluteString == "https://cloud.example.com")
    }

    @Test func serverPathIsKept() async throws {
        let credentials = try LoginCallbackParser.parse("nc://login/server:https://cloud.example.com/nextcloud&user:jane&password:secret")

        #expect(credentials.host.absoluteString == "https://cloud.example.com/nextcloud")
    }

    @Test func plusInUserIsSpace() async throws {
        let credentials = try LoginCallbackParser.parse("nc://login/server:https://cloud.example.com&user:jane+doe&password:secret")

        #expect(credentials.user == "jane doe")
    }

    @Test func percentEncodedValues() async throws {
        let credentials = try LoginCallbackParser.parse("nc://login/server:https://cloud.example.com&user:jane%40example.com&password:se%2Bcret")

        #expect(credentials.user == "jane@example.com")
        #expect(credentials.password == "se+cret")
    }

    @Test func customScheme() async throws {
        let callback = "abc://login/server:https://cloud.example.com&user:jane&password:secret"

        #expect(try LoginCallbackParser.parse(callback, scheme: "abc").user == "jane")

        #expect(throws: QRCodeError.invalidPrefix) {
            try LoginCallbackParser.parse(callback)
        }
    }

    @Test func missingPassword() async throws {
        #expect(throws: QRCodeError.missingPassword) {
            try LoginCallbackParser.parse("nc://login/server:https://cloud.example.com&user:jane")
        }
    }
}
