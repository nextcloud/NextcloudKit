// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Alamofire
@testable import NextcloudKit

final class ShareIntegrationTests: BaseIntegrationXCTestCase {
    func test_createShare_withNote_shouldCreateShare() throws {
        let expectation = expectation(description: "Should finish last callback")
        
        let folderName = "Share\(randomInt)"
        let serverUrl = "\(baseUrl)/remote.php/dav/files/\(userId)"
        let serverUrlFileName = "\(serverUrl)/\(folderName)"

        NextcloudKit.shared.appendSession(account: account, urlBase: baseUrl, user: user, userId: userId, password: password, userAgent: "", nextcloudVersion: 0, groupIdentifier: "")

//        NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: account) { account, ocId, date, error in
//            XCTAssertEqual(self.account, account)
//
//            XCTAssertEqual(NKError.success.errorCode, error.errorCode)
//            XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
//            
//            Thread.sleep(forTimeInterval: 0.2)
//
//            let note = "Test note"
//
//            NextcloudKit.shared.createShare(path: folderName, shareType: 0, shareWith: "nextcloud", note: note, account: "") { account, share, data, error in
//                defer { expectation.fulfill() }
//
//                XCTAssertEqual(self.account, account)
//                XCTAssertEqual(NKError.success.errorCode, error.errorCode)
//                XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
//                XCTAssertEqual(note, share?.note)
//            }
//        }

        waitForExpectations(timeout: 100)
    }
}
