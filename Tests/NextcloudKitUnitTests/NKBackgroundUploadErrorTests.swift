// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Mocker
import Testing
@testable import NextcloudKit

/// Verifies that background uploads read the server's error response like foreground ones.
@Suite("Background upload errors")
struct NKBackgroundUploadErrorTests {
    private func uploadError(statusCode: Int, body: Data) async throws -> NKError {
        let url = try #require(URL(string: "https://cloud.example.com/remote.php/dav/files/alice/\(UUID().uuidString).jpg"))
        let xml = Mock.DataType(name: "xml", headerValue: "application/xml; charset=utf-8")

        Mock(url: url, contentType: xml, statusCode: statusCode, data: [.put: body]).register()

        let delegate = RecordingNextcloudKitDelegate()
        var common = NKCommon()
        common.delegate = delegate

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockingURLProtocol.self]

        let session = URLSession(configuration: configuration, delegate: NKBackground(nkCommonInstance: common), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        session.uploadTask(with: request, from: Data("content".utf8)).resume()

        var errors = delegate.uploadErrors.makeAsyncIterator()

        return try #require(await errors.next())
    }

    @Test("Classifies the error from the WebDAV exception in the response")
    func davException() async throws {
        let body = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
          <s:exception>OCA\\DAV\\Connector\\Sabre\\Exception\\UnsupportedMediaType</s:exception>
          <s:message>Virus Eicar-Test-Signature is detected in the file. Upload cannot be completed.</s:message>
        </d:error>
        """.utf8)

        let error = try await uploadError(statusCode: 415, body: body)

        #expect(error.errorCode == 415)
        #expect(error.kind == .blockedByVirusScan)
        #expect(error.errorDescription == "Virus Eicar-Test-Signature is detected in the file. Upload cannot be completed.")
        #expect(error.responseData == body)
    }

    @Test("Falls back to the status code without a response body")
    func emptyBody() async throws {
        let error = try await uploadError(statusCode: 403, body: Data())

        #expect(error.errorCode == 403)
        #expect(error.kind == .forbidden)
        #expect(error.errorDescription.hasPrefix("403: "))
    }
}
