//
//  NextcloudKitIntegrationTests.swift
//  
//  Created by Milen Pivchev on 23.05.23.
//  Copyright © 2023 Milen Pivchev. All rights reserved.
//
//  Author: Milen Pivchev <milen.pivchev@nextcloud.com>
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import XCTest
@testable import NextcloudKit

final class FilesIntegrationTests: BaseIntegrationXCTestCase {
    func test_createReadDeleteFolder_withProperParams_shouldCreateReadDeleteFolder() throws {
        let expectation = expectation(description: "Should finish last callback")

        let folderName = "TestFolder10"
        let serverUrl = "\(baseUrl)/remote.php/dav/files/\(userId)"
        let serverUrlFileName = "\(serverUrl)/\(folderName)"

        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: baseUrl)

        // Test creating folder
        NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName) { account, ocId, date, error in
            XCTAssertEqual(self.account, account)

            XCTAssertEqual(NKError.success.errorCode, error.errorCode)
            XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)

            Thread.sleep(forTimeInterval: 0.2)

            // Test reading folder, should exist
            NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0") { account, files, data, error in
                XCTAssertEqual(self.account, account)
                XCTAssertEqual(NKError.success.errorCode, error.errorCode)
                XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
                XCTAssertEqual(files[0].fileName, folderName)

                Thread.sleep(forTimeInterval: 0.2)

                // Test deleting folder
                NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName) { account, error in
                    XCTAssertEqual(self.account, account)
                    XCTAssertEqual(NKError.success.errorCode, error.errorCode)
                    XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)

                    Thread.sleep(forTimeInterval: 0.2)

                    // Test reading folder, should NOT exist
                    NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0") { account, files, data, error in
                        defer { expectation.fulfill() }

                        XCTAssertEqual(404, error.errorCode)
                        XCTAssertEqual(self.account, account)
                        XCTAssertTrue(files.isEmpty)
                    }
                }
            }
        }

        waitForExpectations(timeout: 100)
    }
}
