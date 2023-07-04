//
//  SearchIntegrationTests.swift
//  
// 
//  Created by Milen Pivchev on 04.07.23.
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
import SwiftyJSON
@testable import NextcloudKit

final class SearchIntegrationTests: BaseIntegrationXCTestCase {
    func test_unifiedSearch_withProperParams_shouldShowResults() throws {
        let expectation = expectation(description: "Should finish last callback")

        let serverUrl = "\(baseUrl)/remote.php/dav/files/\(userId)"
        let serverUrlFileName1 = "\(serverUrl)/SearchFolder"
        let serverUrlFileName2 = "\(serverUrl)/SearchFile"

        var updateCount = 0
        var providerCount = 0

        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: baseUrl)

        // Create 2 files/folders
        NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName1) { account, ocId, date, error in
            Thread.sleep(forTimeInterval: 0.2)

            NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName2) { account, ocId, date, error in
//            NextcloudKit.shared.createUrlRichdocuments(fileID: serverUrlFileName2) { account, url, data, error in
                Thread.sleep(forTimeInterval: 0.2)

                // Check if search returns files
                NextcloudKit.shared.unifiedSearch(term: "Search") { request in

                } providers: { account, searchProviders in
                    providerCount = searchProviders!.count
                } update: { account, searchResult, provider, error in
                    if provider.id == "files" {
                        XCTAssertEqual(searchResult!.entries.count, 2)
                    } else {
                        XCTAssertEqual(searchResult!.entries.count, 0)
                    }

                    updateCount += 1
                } completion: { account, data, error in
                    defer { expectation.fulfill() }
                    XCTAssertEqual(NKError.success.errorCode, error.errorCode)
                    XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
                    XCTAssertEqual(updateCount, providerCount)
                    print(error)
                }

            }
        }
        waitForExpectations(timeout: 100)
    }
}
