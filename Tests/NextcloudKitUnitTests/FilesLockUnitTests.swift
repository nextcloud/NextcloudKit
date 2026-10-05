// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import XCTest
@testable import NextcloudKit

final class FilesLockUnitTests: XCTestCase {
    private let account = "files-lock-unit-test-\(UUID().uuidString)"
    private let fileURL = URL(string: "https://example.invalid/remote.php/dav/files/user/file.txt")!

    private func assertFailure(status: Int, data: Data, shouldLock: Bool, file: StaticString = #filePath, line: UInt = #line) async {
        TestURLProtocol.setReply(status: status, data: data)

        do {
            _ = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                        shouldLock: shouldLock,
                                                        account: account)
            XCTFail("Expected HTTP \(status) to throw", file: file, line: line)
        } catch {
            let error = error as? NKError
            XCTAssertEqual(error?.errorCode, status, file: file, line: line)
            XCTAssertEqual(error?.responseData, data, file: file, line: line)
        }
        assertRequest(method: shouldLock ? "LOCK" : "UNLOCK", file: file, line: line)
    }

    override func tearDown() {
        TestURLProtocol.reset()
        super.tearDown()
    }

    func test_lockUnlockFileResult_withLockResponse_returnsLockAndETag() async throws {
        TestURLProtocol.setReply(status: 200, data: lockData(etag: "\"etag-b\"", ownerType: .token))
        let capabilities = NKCapabilities.Capabilities()
        capabilities.filesLockTypes = true
        await NKCapabilities.shared.setCapabilities(for: account, capabilities: capabilities)

        let result = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                               type: .token,
                                                               shouldLock: true,
                                                               account: account)

        XCTAssertEqual(result.etag, "etag-b")
        XCTAssertEqual(result.lock?.etag, "etag-b")
        XCTAssertEqual(result.lock?.ownerType, .token)
        assertRequest(method: "LOCK", lockType: .token)
    }

    func test_lockUnlockFileResult_withUnlockResponse_returnsETagWithoutLock() async throws {
        TestURLProtocol.setReply(status: 200, data: unlockData(etag: "etag-c"))

        let result = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                               shouldLock: false,
                                                               account: account)

        XCTAssertNil(result.lock)
        XCTAssertEqual(result.etag, "etag-c")
        assertRequest(method: "UNLOCK")
    }

    func test_lockUnlockFileResult_withMissingETag_returnsNilValues() async throws {
        TestURLProtocol.setReply(status: 200, data: unlockData())

        let result = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                               shouldLock: false,
                                                               account: account)

        XCTAssertNil(result.lock)
        XCTAssertNil(result.etag)
    }

    func test_lockUnlockFileResult_withNoContentResponse_returnsEmptyResult() async throws {
        TestURLProtocol.setReply(status: 204, data: Data())

        let result = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                               shouldLock: false,
                                                               account: account)

        XCTAssertNil(result.lock)
        XCTAssertNil(result.etag)
    }

    func test_lockUnlockFileResult_withEmptyOKResponse_throws() async {
        TestURLProtocol.setReply(status: 200, data: Data())

        do {
            _ = try await makeKit().lockUnlockFileResult(serverUrlFileName: fileURL.absoluteString,
                                                          shouldLock: false,
                                                          account: account)
            XCTFail("An empty HTTP 200 response must not be treated as a successful unlock")
        } catch {
            XCTAssertTrue(error is NKError)
        }
    }

    func test_lockUnlockFileResult_whenLockIsOwnedByAnotherUser_throwsWithLockProperties() async {
        await assertFailure(status: 423, data: lockData(etag: "etag-existing"), shouldLock: true)
    }

    func test_lockUnlockFileResult_whenUnlockIsUnauthorized_throwsWithLockProperties() async {
        await assertFailure(status: 423, data: lockData(etag: "etag-existing"), shouldLock: false)
    }

    func test_lockUnlockFileResult_whenAlreadyUnlocked_throwsWithUnlockedProperties() async {
        await assertFailure(status: 412, data: unlockData(etag: "etag-unlocked"), shouldLock: false)
    }

    func test_lockUnlockFileResult_withServerError_throws() async {
        let data = Data("""
        <?xml version="1.0"?>
        <d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
            <s:exception>Sabre\\DAV\\Exception</s:exception>
            <s:message>Internal server error</s:message>
        </d:error>
        """.utf8)
        await assertFailure(status: 500, data: data, shouldLock: false)
    }

    func test_lockUnlockFile_existingAsyncAPI_preservesLockOptionality() async throws {
        TestURLProtocol.setReply(status: 200, data: lockData(etag: "etag-b"))
        let lock = try await makeKit().lockUnlockFile(serverUrlFileName: fileURL.absoluteString,
                                                       shouldLock: true,
                                                       account: account)
        XCTAssertEqual(lock?.etag, "etag-b")

        TestURLProtocol.setReply(status: 200, data: unlockData(etag: "etag-c"))
        let unlock = try await makeKit().lockUnlockFile(serverUrlFileName: fileURL.absoluteString,
                                                         shouldLock: false,
                                                         account: account)
        XCTAssertNil(unlock)
    }

    private func assertRequest(method: String, lockType: NKLockType? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let requests = TestURLProtocol.requests
        XCTAssertEqual(requests.count, 1, file: file, line: line)
        XCTAssertEqual(requests.first?.httpMethod, method, file: file, line: line)
        XCTAssertEqual(requests.first?.url, fileURL, file: file, line: line)
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "X-User-Lock"), "1", file: file, line: line)
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "X-User-Lock-Type"),
                       lockType.map { String($0.rawValue) }, file: file, line: line)
    }

    private func makeKit() -> NextcloudKit {
        let kit = NextcloudKit()
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [TestURLProtocol.self]
        let session = NKSession(nkCommonInstance: kit.nkCommonInstance,
                                urlBase: "https://example.invalid",
                                user: "user",
                                userId: "user",
                                password: "password",
                                account: account,
                                userAgent: "NextcloudKit unit test",
                                groupIdentifier: "",
                                httpMaximumConnectionsPerHost: 6,
                                httpMaximumConnectionsPerHostInDownload: 6,
                                httpMaximumConnectionsPerHostInUpload: 6,
                                sessionDataOverride: Session(configuration: configuration))
        kit.nkCommonInstance.nksessions.append(session)
        return kit
    }

    private func lockData(etag: String?, ownerType: NKLockType = .user) -> Data {
        let etagElement = etag.map { "<d:getetag>\($0)</d:getetag>" } ?? ""
        let tokenElement = ownerType == .token ? "<nc:lock-token>files_lock/test-token</nc:lock-token>" : ""
        let xml = """
        <?xml version="1.0"?>
        <d:prop xmlns:d="DAV:" xmlns:nc="http://nextcloud.org/ns">
            <nc:lock>1</nc:lock>
            <nc:lock-owner>user-id</nc:lock-owner>
            <nc:lock-owner-type>\(ownerType.rawValue)</nc:lock-owner-type>
            <nc:lock-owner-displayname>User Name</nc:lock-owner-displayname>
            <nc:lock-owner-editor/>
            <nc:lock-time>1</nc:lock-time>
            <nc:lock-timeout>60</nc:lock-timeout>
            \(tokenElement)
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
            <nc:lock/>
            <nc:lock-owner-type/>
            <nc:lock-owner/>
            <nc:lock-owner-displayname/>
            <nc:lock-owner-editor/>
            <nc:lock-time/>
            <nc:lock-timeout/>
            <nc:lock-token/>
            \(etagElement)
        </d:prop>
        """
        return Data(xml.utf8)
    }
}
