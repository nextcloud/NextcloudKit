//
//  NextcloudKitUnitTests.swift
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
import Alamofire
import Mocker
import SwiftyJSON

class NextcloudKitUnitTests: XCTestCase {
    private let serverUrl = "https://cloud.nextcloud.com"
    private let url = URL(string: "https://cloud.nextcloud.com/index.php/login/v2")!
    private lazy var requestExpectation = expectation(description: "Request should finish")

    func `test_log_in_poll_successful`() {
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        let sessionManager = Alamofire.Session(configuration: configuration)
        let mockJson: Data = try! Data(contentsOf: MockedData.mockJson)


        let mock = Mock(url: url, dataType: .json, statusCode: 200, data: [
            .post: mockJson
        ])
        mock.register()


        NextcloudKit.shared.setCustomSessionManager(sessionManager: sessionManager)

        NextcloudKit.shared.getLoginFlowV2(serverUrl: serverUrl) { token, endpoint, login, data, error in
            defer { self.requestExpectation.fulfill() }
            let json = JSON(mockJson)

            let mockToken = json["poll"]["token"].string
            let mockEndpoint = json["poll"]["endpoint"].string
            let mockLogin = json["login"].string

            XCTAssertEqual(token, mockToken)
            XCTAssertEqual(endpoint, mockEndpoint)
            XCTAssertEqual(login, mockLogin)
        }

        wait(for: [requestExpectation])
    }


    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}

fileprivate final class MockedData {
    public static let mockJson: URL = Bundle.module.url(forResource: "PollMock", withExtension: "json")!
}
