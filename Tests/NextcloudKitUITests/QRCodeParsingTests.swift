// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

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
}
