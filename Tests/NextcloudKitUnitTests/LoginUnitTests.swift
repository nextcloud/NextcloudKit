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

class LoginUnitTests: XCTestCase {
    private lazy var serverUrl = "https://localhost:8080"
    private lazy var endpoint = "/index.php/login/v2"
    private lazy var fullUrlString = serverUrl + endpoint
    private lazy var fullUrl = URL(string: fullUrlString)!

    // Create a mock of Alamofire's session manager config
    private lazy var mockSessionManager = {
        let config = URLSessionConfiguration.af.default
        config.protocolClasses = [MockingURLProtocol.self]
        return config
    }

    override func setUp() {
        // Set our mock session manager as the one the API is going to use
        NextcloudKit.shared.nkCommonInstance.sessionConfiguration = mockSessionManager()
    }

    // Format of function names should be: func test_functionName_withCircumstances_shouldExpectation() {}
    func test_getLoginFlowV2_withGoodStatusCode_requestShouldBeSuccessful() {
        // Create a mock of the json we would expect to get from the original call
        let mockJsonData: Data = try! Data(contentsOf: MockedData.mockJson)

        // Create a mock session request and register it
        var mock = Mock(url: fullUrl, dataType: .json, statusCode: 200, data: [
            .post: mockJsonData
        ])

        mock.onRequest = { request, _ in
            let url = request.url?.absoluteString
            XCTAssertEqual(self.fullUrlString, url)
        }
        mock.register()

        NextcloudKit.shared.nkCommonInstance.sessionConfiguration = mockSessionManager()

        // Now we call the function we want to test; it will use the mock session and request and return the mock data
        NextcloudKit.shared.getLoginFlowV2(serverUrl: serverUrl) { token, endpoint, login, data, error in
            let json = JSON(mockJsonData)

            let mockToken = json["poll"]["token"].string
            let mockEndpoint = json["poll"]["endpoint"].string
            let mockLogin = json["login"].string

            // Test if the returned response data is what we would expect
            XCTAssertEqual(token, mockToken)
            XCTAssertEqual(endpoint, mockEndpoint)
            XCTAssertEqual(login, mockLogin)
            XCTAssertEqual(data, mockJsonData)
            XCTAssertEqual(NKError.success, error)
        }
    }

    func test_getLoginFlowV2_withBadStatusCode_requestShouldFail() {
        // Create a mock session request and register it
        var mock = Mock(url: fullUrl, dataType: .json, statusCode: 500, data: [.delete: Data()])

        mock.onRequest = { request, _ in
            let url = request.url?.absoluteString
            XCTAssertEqual(self.fullUrlString, url)
        }
        mock.register()

        // Now we call the function we want to test; it will use the mock session and request and return the mock data
        NextcloudKit.shared.getLoginFlowV2(serverUrl: serverUrl) { token, endpoint, login, data, error in
            XCTAssertNotNil(error)
            XCTAssertNil(token)
            XCTAssertNil(endpoint)
            XCTAssertNil(login)
            XCTAssertNil(data)
        }
    }

    func test_getLoginFlowV2_withBadUrl_requestShouldFail() {
        // Create a mock session request and register it
        var mock = Mock(url: fullUrl, dataType: .json, statusCode: 200, data: [.delete: Data()])

        mock.onRequest = { request, _ in
            let url = request.url?.absoluteString
            XCTAssertNotEqual(self.fullUrlString, url)
        }
        mock.register()

        // Set our mock session manager as the one the API is going to use
        NextcloudKit.shared.nkCommonInstance.sessionConfiguration = mockSessionManager()

        // Now we call the function we want to test; it will use the mock session and request and return the mock data
        NextcloudKit.shared.getLoginFlowV2(serverUrl: "badUrl") { token, endpoint, login, data, error in
            XCTAssertNotNil(error)
            XCTAssertNil(token)
            XCTAssertNil(endpoint)
            XCTAssertNil(login)
            XCTAssertNil(data)
        }
    }
}

fileprivate final class MockedData {
    public static let mockJson: URL = Bundle.module.url(forResource: "PollMock", withExtension: "json")!
}
