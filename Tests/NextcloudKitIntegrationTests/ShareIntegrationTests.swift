//
// SPDX-FileCopyrightText: 2023 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//

import XCTest
@testable import NextcloudKit

final class ShareIntegrationTests: BaseIntegrationXCTestCase {
    func test_createShare_withNote_shouldCreateShare() throws {
        let expectation = expectation(description: "Should finish last callback")
        
        let folderName = "Share\(randomInt)"
        let serverUrl = "\(baseUrl)/remote.php/dav/files/\(userId)"
        let serverUrlFileName = "\(serverUrl)/\(folderName)"

        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: baseUrl)

        NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: account) { account, ocId, date, error in
            XCTAssertEqual(self.account, account)

            XCTAssertEqual(NKError.success.errorCode, error.errorCode)
            XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
            
            Thread.sleep(forTimeInterval: 0.2)

            let note = "Test note"

            NextcloudKit.shared.createShare(path: folderName, shareType: 0, shareWith: "nextcloud", note: note, account: account) { account, share, data, error in
                defer { expectation.fulfill() }

                XCTAssertEqual(self.account, account)
                XCTAssertEqual(NKError.success.errorCode, error.errorCode)
                XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
                XCTAssertEqual(note, share?.note)
            }
        }

        waitForExpectations(timeout: 100)
    }
}
