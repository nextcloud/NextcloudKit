// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import NextcloudKit

@Suite("NKLock parsing")
struct NKLockUnitTests {
    private func makeLockData(etagElement: String = "") -> Data {
        let xml = """
        <?xml version="1.0"?>
        <d:prop xmlns:d="DAV:" xmlns:nc="http://nextcloud.org/ns">
            <nc:lock>1</nc:lock>
            <nc:lock-owner>user-id</nc:lock-owner>
            <nc:lock-owner-editor>text</nc:lock-owner-editor>
            <nc:lock-owner-type>\(NKLockType.token.rawValue)</nc:lock-owner-type>
            <nc:lock-owner-displayname>User Name</nc:lock-owner-displayname>
            <nc:lock-time>1</nc:lock-time>
            <nc:lock-timeout>60</nc:lock-timeout>
            <nc:lock-token>files_lock/test-token</nc:lock-token>
            \(etagElement)
        </d:prop>
        """

        return Data(xml.utf8)
    }

    @Test("Parses quoted ETag from LOCK response")
    func parsesQuotedETag() {
        let lock = NKLock(data: makeLockData(etagElement: "<d:getetag>\"etag-after-lock\"</d:getetag>"))

        #expect(lock != nil)
        #expect(lock?.token == "files_lock/test-token")
        #expect(lock?.etag == "etag-after-lock")
    }

    @Test("Missing ETag keeps lock parsing valid")
    func missingETagDoesNotFailParsing() {
        let lock = NKLock(data: makeLockData())

        #expect(lock != nil)
        #expect(lock?.etag == nil)
    }

    @Test("Unquoted ETag is preserved")
    func preservesUnquotedETag() {
        let lock = NKLock(data: makeLockData(etagElement: "<d:getetag>etag-after-lock</d:getetag>"))

        #expect(lock != nil)
        #expect(lock?.etag == "etag-after-lock")
    }
}
