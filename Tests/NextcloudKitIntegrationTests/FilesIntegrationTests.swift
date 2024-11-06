// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import NextcloudKit

final class FilesIntegrationTests: BaseIntegrationXCTestCase {
//    func test_createReadDeleteFolder_withProperParams_shouldCreateReadDeleteFolder() throws {
//        let expectation = expectation(description: "Should finish last callback")
//        let folderName = "TestFolder\(randomInt)"
//        let serverUrl = "\(TestConstants.server)/remote.php/dav/files/\(TestConstants.username)"
//        let serverUrlFileName = "\(serverUrl)/\(folderName)"
//
//        NextcloudKit.shared.appendSession(account: TestConstants.account, urlBase: TestConstants.server, user: TestConstants.username, userId: TestConstants.username, password: TestConstants.password, userAgent: "", nextcloudVersion: 0, groupIdentifier: "")
//
//        // Test creating folder
//        NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: TestConstants.account) { account, ocId, date, _, error in
//            XCTAssertEqual(TestConstants.account, account)
//
//            XCTAssertEqual(NKError.success.errorCode, error.errorCode)
//            XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
//
//            Thread.sleep(forTimeInterval: 0.2)
//
//            // Test reading folder, should exist
//            NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", account: account) { account, files, data, error in
//                XCTAssertEqual(TestConstants.account, account)
//                XCTAssertEqual(NKError.success.errorCode, error.errorCode)
//                XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
//                XCTAssertEqual(files?[0].fileName, folderName)
//
//                Thread.sleep(forTimeInterval: 0.2)
//
//                // Test deleting folder
//                NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: account) { account, _, error in
//                    XCTAssertEqual(TestConstants.account, account)
//                    XCTAssertEqual(NKError.success.errorCode, error.errorCode)
//                    XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
//
//                    Thread.sleep(forTimeInterval: 0.2)
//
//                    // Test reading folder, should NOT exist
//                    NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", account: account) { account, files, data, error in
//                        defer { expectation.fulfill() }
//
//                        XCTAssertEqual(404, error.errorCode)
//                        XCTAssertEqual(TestConstants.account, account)
//                        XCTAssertTrue(files?.isEmpty ?? false)
//                    }
//                }
//            }
//        }
//
//        waitForExpectations(timeout: 100)
//    }
}
