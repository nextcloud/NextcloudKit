// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Alamofire
@testable import NextcloudKit

/// Unit tests for chunk-assembly MOVE failures and deriving the assembled file from response headers.
final class ChunkedUploadAssemblyTests: XCTestCase {
    private func makeKit() -> NextcloudKit {
        #if swift(<6.0)
        return NextcloudKit.shared
        #else
        return NextcloudKit()
        #endif
    }

    private func uploadThroughMockedAssembly(moveStatus: Int) async throws -> (error: NKError?, file: NKFile?) {
        let kit = makeKit()
        let account = UUID().uuidString
        let urlBase = "https://assembly-\(moveStatus).test"
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [ChunkedUploadURLProtocol.self]
        let session = NKSession(nkCommonInstance: kit.nkCommonInstance,
                                urlBase: urlBase,
                                user: "user",
                                userId: "user",
                                password: "password",
                                account: account,
                                userAgent: "NextcloudKitTests",
                                groupIdentifier: "",
                                httpMaximumConnectionsPerHost: 1,
                                httpMaximumConnectionsPerHostInDownload: 1,
                                httpMaximumConnectionsPerHostInUpload: 1,
                                sessionDataOverride: Alamofire.Session(configuration: configuration))
        kit.nkCommonInstance.nksessions.append(session)
        defer { kit.nkCommonInstance.nksessions.remove(account: account) }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("chunk".utf8).write(to: directory.appendingPathComponent("source.txt"))
        try Data("chunk".utf8).write(to: directory.appendingPathComponent("00001"))

        do {
            let result = try await kit.uploadChunkAsync(directory: directory.path,
                                                        fileName: "source.txt",
                                                        date: nil, creationDate: nil,
                                                        serverUrl: urlBase + "/remote.php/dav/files/user",
                                                        chunkFolder: "chunks",
                                                        filesChunk: [(fileName: "00001", size: 5)],
                                                        chunkSize: 5,
                                                        account: account)
            return (nil, result.file)
        } catch let error as NKError {
            return (error, nil)
        }
    }

    func test_failedAssemblyMove_throwsServerError() async throws {
        let result = try await uploadThroughMockedAssembly(moveStatus: 507)
        XCTAssertEqual(result.error?.errorCode, 507)
    }

    func test_failedAssemblyMove_throwsPreconditionError() async throws {
        let result = try await uploadThroughMockedAssembly(moveStatus: 412)
        XCTAssertEqual(result.error?.errorCode, 412)
    }

    func test_successfulAssemblyMove_returnsFile() async throws {
        let result = try await uploadThroughMockedAssembly(moveStatus: 201)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.file?.ocId, "assembled-file-id")
    }

    func test_assembledFile_withOCFileId_derivesNKFileFromHeaders() {
        let kit = makeKit()
        let headers: [AnyHashable: Any] = [
            "OC-FileID": "00000123oc9wxyzinstance",
            "OC-ETag": "\"abc123\"",
            "Date": "Wed, 07 Jun 2026 09:04:51 GMT"
        ]

        let file = kit.assembledFile(fromMoveResponseHeaders: headers,
                                     account: "user https://cloud.example.com",
                                     fileName: "1.1Gb.mp4",
                                     serverUrl: "https://cloud.example.com/remote.php/dav/files/user",
                                     size: 1_181_116_006,
                                     fallbackDate: nil)

        XCTAssertNotNil(file, "OC-FileID present should yield an NKFile, not nil")
        XCTAssertEqual(file?.ocId, "00000123oc9wxyzinstance")
        XCTAssertEqual(file?.etag, "abc123", "normalizedETag should strip the surrounding quotes")
        XCTAssertEqual(file?.size, 1_181_116_006)
        XCTAssertEqual(file?.fileName, "1.1Gb.mp4")
        XCTAssertEqual(file?.account, "user https://cloud.example.com")
    }

    func test_assembledFile_isCaseInsensitiveOnHeaderNames() {
        let kit = makeKit()
        // Lower-cased header keys must resolve the same as canonical casing.
        let headers: [AnyHashable: Any] = ["oc-fileid": "fid", "oc-etag": "\"e\""]

        let file = kit.assembledFile(fromMoveResponseHeaders: headers,
                                     account: "a", fileName: "f", serverUrl: "s", size: 1, fallbackDate: nil)

        XCTAssertEqual(file?.ocId, "fid")
        XCTAssertEqual(file?.etag, "e")
    }

    func test_assembledFile_prefersOCETagOverPlainETag() {
        let kit = makeKit()
        let headers: [AnyHashable: Any] = [
            "OC-FileID": "fid",
            "OC-ETag": "\"oc-etag-value\"",
            "ETag": "\"plain-etag-value\""
        ]

        let file = kit.assembledFile(fromMoveResponseHeaders: headers,
                                     account: "a", fileName: "f", serverUrl: "s", size: 1, fallbackDate: nil)

        XCTAssertEqual(file?.etag, "oc-etag-value", "OC-ETag should win over the standard ETag")
    }

    func test_assembledFile_fallsBackToPlainETagWhenNoOCETag() {
        let kit = makeKit()
        let headers: [AnyHashable: Any] = ["OC-FileID": "fid", "ETag": "\"plain\""]

        let file = kit.assembledFile(fromMoveResponseHeaders: headers,
                                     account: "a", fileName: "f", serverUrl: "s", size: 1, fallbackDate: nil)

        XCTAssertEqual(file?.etag, "plain")
    }

    func test_assembledFile_withoutOCFileId_returnsNilToTriggerReadbackFallback() {
        let kit = makeKit()
        let headers: [AnyHashable: Any] = ["ETag": "\"x\""] // no OC-FileID (e.g. 202 async assembly)

        let file = kit.assembledFile(fromMoveResponseHeaders: headers,
                                     account: "a", fileName: "f", serverUrl: "s", size: 1, fallbackDate: nil)

        XCTAssertNil(file, "Absent OC-FileID must return nil so the caller falls back to a read-back")
    }

    func test_assembledFile_withNilHeaders_returnsNil() {
        let kit = makeKit()

        let file = kit.assembledFile(fromMoveResponseHeaders: nil,
                                     account: "a", fileName: "f", serverUrl: "s", size: 1, fallbackDate: nil)

        XCTAssertNil(file)
    }

    func test_assembledFile_usesFallbackDateWhenNoDateHeader() {
        let kit = makeKit()
        let fallback = Date(timeIntervalSince1970: 1_000_000)
        let headers: [AnyHashable: Any] = ["OC-FileID": "fid"] // no Date header

        let file = kit.assembledFile(fromMoveResponseHeaders: headers,
                                     account: "a", fileName: "f", serverUrl: "s", size: 1, fallbackDate: fallback)

        XCTAssertEqual(file?.date, fallback)
    }
}
