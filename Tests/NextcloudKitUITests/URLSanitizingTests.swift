// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import NextcloudKitUI
import Testing

///
/// Test subject which conforms to ``URLSanitizing``.
///
struct URLSanitizingTestSubject: URLSanitizing {}

///
/// Tests for ``URLSanitizing``.
///
struct URLSanitizingTests {
    let testSubject: URLSanitizingTestSubject

    init() {
        testSubject = URLSanitizingTestSubject()
    }

    @Test func emptyString() async throws {
        try #require(testSubject.sanitize("") == nil)
    }

    @Test func invalidScheme() async throws {
        try #require(testSubject.sanitize("ssh://www.nextcloud.com") == nil)
    }

    @Test func validURL() async throws {
        try #require(testSubject.sanitize("https://www.nextcloud.com") != nil)
    }

    @Test func appendsMissingRootPath() async throws {
        let sanitized = testSubject.sanitize("https://www.nextcloud.com")?.absoluteString
        try #require(sanitized == "https://www.nextcloud.com/")
    }

    @Test(arguments: ["https://www.nextcloud.com/nextcloud", "https://www.nextcloud.com/nextcloud/"]) func pathPrefix(_ pathPrefix: String) async throws {
        let sanitized = try #require(testSubject.sanitize(pathPrefix))
        #expect(sanitized.absoluteString == "https://www.nextcloud.com/nextcloud/")
    }

    @Test(arguments: ["https://www.nextcloud.com/index.php", "https://www.nextcloud.com/index.php/"]) func phpPathSuffix(_ pathPrefix: String) async throws {
        let sanitized = try #require(testSubject.sanitize(pathPrefix))
        #expect(sanitized.absoluteString == "https://www.nextcloud.com/")
    }
}
