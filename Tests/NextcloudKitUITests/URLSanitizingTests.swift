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

    @Test(arguments: ["", "   ", "\n"]) func emptyInput(_ input: String) async throws {
        #expect(testSubject.sanitize(input) == nil)
    }

    @Test(arguments: ["ssh://www.nextcloud.com", "ftp://www.nextcloud.com"]) func invalidScheme(_ input: String) async throws {
        #expect(testSubject.sanitize(input) == nil)
    }

    @Test(arguments: ["https://", "http:///nextcloud"]) func missingHost(_ input: String) async throws {
        #expect(testSubject.sanitize(input) == nil)
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

    @Test(arguments: ["https://www.nextcloud.com/nextcloud/index.php", "https://www.nextcloud.com/nextcloud/index.php/"]) func phpPathSuffixBelowPathPrefix(_ input: String) async throws {
        let sanitized = try #require(testSubject.sanitize(input))
        #expect(sanitized.absoluteString == "https://www.nextcloud.com/nextcloud/")
    }

    @Test(arguments: [
        ("cloud.example.com", "https://cloud.example.com/"),
        ("cloud.example.com/nextcloud", "https://cloud.example.com/nextcloud/"),
        ("localhost:8080", "https://localhost:8080/"),
        ("cloud.example.com:8443/nextcloud", "https://cloud.example.com:8443/nextcloud/"),
        ("//cloud.example.com", "https://cloud.example.com/")
    ]) func missingScheme(_ input: String, _ expected: String) async throws {
        let sanitized = try #require(testSubject.sanitize(input))
        #expect(sanitized.absoluteString == expected)
    }

    @Test(arguments: [
        ("https:/cloud.example.com", "https://cloud.example.com/"),
        ("https:cloud.example.com", "https://cloud.example.com/"),
        ("HTTPS:/cloud.example.com/nextcloud", "https://cloud.example.com/nextcloud/"),
        ("http:/localhost:8080", "http://localhost:8080/")
    ]) func mistypedSchemeSlashes(_ input: String, _ expected: String) async throws {
        let sanitized = try #require(testSubject.sanitize(input))
        #expect(sanitized.absoluteString == expected)
    }

    @Test func trimsWhitespaceAndNewlines() async throws {
        let sanitized = try #require(testSubject.sanitize("  https://cloud.example.com \n"))
        #expect(sanitized.absoluteString == "https://cloud.example.com/")
    }

    @Test func dropsQueryAndFragment() async throws {
        let sanitized = try #require(testSubject.sanitize("https://cloud.example.com/nextcloud/?redirect=1#top"))
        #expect(sanitized.absoluteString == "https://cloud.example.com/nextcloud/")
    }

    @Test func keepsInsecureHTTPByDefault() async throws {
        let sanitized = try #require(testSubject.sanitize("http://localhost:8080"))
        #expect(sanitized.absoluteString == "http://localhost:8080/")
    }

    @Test func upgradesInsecureHTTP() async throws {
        let sanitized = try #require(testSubject.sanitize("http://cloud.example.com/nextcloud", upgradingInsecureHTTP: true))
        #expect(sanitized.absoluteString == "https://cloud.example.com/nextcloud/")
    }
}
