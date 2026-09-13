// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Mocker
import XCTest
@testable import NextcloudKit

final class FilesLockUnitTests: XCTestCase {
    private let account = "files-lock-unit-test"
    private let fileURL = URL(string: "https://example.invalid/remote.php/dav/files/user/file.txt")!
    private let xmlDataType = Mock.DataType(name: "xml", headerValue: "application/xml")

    override func tearDown() {
        Mocker.removeAll()
        super.tearDown()
    }

    func test_lockUnlockFileResult_withLockResponse_returnsLockAndETag() async throws {
        var mock = Mock(url: fileURL,
                        dataType: xmlDataType,
                        statusCode: 200,
                        data: [HTTPMethod(rawValue: "LOCK"): lockData(etag: "\"etag-b\"")])
        mock.register()

        let result = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                               shouldLock: true,
                                                               account: account)

        XCTAssertEqual(result.etag, "etag-b")
        XCTAssertEqual(result.lock?.etag, "etag-b")
    }

    func test_lockUnlockFileResult_withUnlockResponse_returnsETagWithoutLock() async throws {
        var mock = Mock(url: fileURL,
                        dataType: xmlDataType,
                        statusCode: 200,
                        data: [HTTPMethod(rawValue: "UNLOCK"): unlockData(etag: "etag-c")])
        mock.register()

        let result = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                               shouldLock: false,
                                                               account: account)

        XCTAssertNil(result.lock)
        XCTAssertEqual(result.etag, "etag-c")
    }

    func test_lockUnlockFileResult_withEmptyOrMissingETag_returnsNilValues() async throws {
        var missingETagMock = Mock(url: fileURL,
                                   dataType: xmlDataType,
                                   statusCode: 200,
                                   data: [HTTPMethod(rawValue: "UNLOCK"): unlockData()])
        missingETagMock.register()

        let missingETagResult = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                                          shouldLock: false,
                                                                          account: account)

        XCTAssertNil(missingETagResult.lock)
        XCTAssertNil(missingETagResult.etag)

        Mocker.removeAll()
        var emptyResponseMock = Mock(url: fileURL,
                                     dataType: xmlDataType,
                                     statusCode: 200,
                                     data: [HTTPMethod(rawValue: "UNLOCK"): Data()])
        emptyResponseMock.register()

        let emptyResponseResult = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                                            shouldLock: false,
                                                                            account: account)

        XCTAssertNil(emptyResponseResult.lock)
        XCTAssertNil(emptyResponseResult.etag)
    }

    func test_lockUnlockFileResult_withFailure_throws() async {
        for statusCode in [412, 500] {
            var mock = Mock(url: fileURL,
                            dataType: xmlDataType,
                            statusCode: statusCode,
                            data: [HTTPMethod(rawValue: "UNLOCK"): Data()])
            mock.register()

            do {
                _ = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                              shouldLock: false,
                                                              account: account)
                XCTFail("Expected HTTP \(statusCode) to throw")
            } catch {
                XCTAssertEqual((error as? NKError)?.errorCode, statusCode)
            }

            Mocker.removeAll()
        }
    }

    func test_lockUnlockFile_existingAsyncAPI_preservesLockOptionality() async throws {
        var lockMock = Mock(url: fileURL,
                            dataType: xmlDataType,
                            statusCode: 200,
                            data: [HTTPMethod(rawValue: "LOCK"): lockData(etag: "etag-b")])
        lockMock.register()

        let lock = try await makeKit().lockUnlockFile(serverUrlFileName: fileURL.absoluteString,
                                                       shouldLock: true,
                                                       account: account)
        XCTAssertNotNil(lock)

        Mocker.removeAll()
        var unlockMock = Mock(url: fileURL,
                              dataType: xmlDataType,
                              statusCode: 200,
                              data: [HTTPMethod(rawValue: "UNLOCK"): unlockData(etag: "etag-c")])
        unlockMock.register()

        let unlock = try await makeKit().lockUnlockFile(serverUrlFileName: fileURL.absoluteString,
                                                         shouldLock: false,
                                                         account: account)
        XCTAssertNil(unlock)
    }

    private func makeKit() -> NextcloudKit {
        let kit = NextcloudKit()
        kit.appendSession(account: account,
                          urlBase: "https://example.invalid",
                          user: "user",
                          userId: "user",
                          password: "password",
                          userAgent: "NextcloudKit unit test",
                          groupIdentifier: "")
        return kit
    }

    private func lockData(etag: String?) -> Data {
        let etagElement = etag.map { "<d:getetag>\($0)</d:getetag>" } ?? ""
        let xml = """
        <?xml version="1.0"?>
        <d:prop xmlns:d="DAV:" xmlns:nc="http://nextcloud.org/ns">
            <nc:lock>1</nc:lock>
            <nc:lock-owner>user-id</nc:lock-owner>
            <nc:lock-owner-type>\(NKLockType.token.rawValue)</nc:lock-owner-type>
            <nc:lock-owner-displayname>User Name</nc:lock-owner-displayname>
            <nc:lock-time>1</nc:lock-time>
            <nc:lock-timeout>60</nc:lock-timeout>
            \(etagElement)
        </d:prop>
        """
        return Data(xml.utf8)
    }

    private func unlockData(etag: String? = nil) -> Data {
        let etagElement = etag.map { "<d:getetag>\($0)</d:getetag>" } ?? ""
        let xml = """
        <?xml version="1.0"?>
        <d:prop xmlns:d="DAV:" xmlns:nc="http://nextcloud.org/ns">
            <nc:lock>0</nc:lock>
            \(etagElement)
        </d:prop>
        """
        return Data(xml.utf8)
    }
}
