// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

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
//        NextcloudKit.shared.nkCommonInstance.sessionConfiguration = mockSessionManager()
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

//        NextcloudKit.shared.nkCommonInstance.sessionConfiguration = mockSessionManager()

        // Now we call the function we want to test; it will use the mock session and request and return the mock data
#if swift(<6.0)
        let ncKit = NextcloudKit.shared
#else
        let ncKit = NextcloudKit()
#endif
        ncKit.getLoginFlowV2(serverUrl: serverUrl) { token, endpoint, login, data, error in
            let json = JSON(mockJsonData)

            let mockToken = json["poll"]["token"].string
            let mockEndpoint = json["poll"]["endpoint"].string
            let mockLogin = json["login"].string

            // Test if the returned response data is what we would expect
            XCTAssertEqual(token, mockToken)
            XCTAssertEqual(endpoint, mockEndpoint)
            XCTAssertEqual(login, mockLogin)
//            XCTAssertEqual(data, mockJsonData)
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

#if swift(<6.0)
        let ncKit = NextcloudKit.shared
#else
        let ncKit = NextcloudKit()
#endif
        // Now we call the function we want to test; it will use the mock session and request and return the mock data
        ncKit.getLoginFlowV2(serverUrl: serverUrl) { token, endpoint, login, data, error in
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
//        NextcloudKit.shared.nkCommonInstance.sessionConfiguration = mockSessionManager()

#if swift(<6.0)
        let ncKit = NextcloudKit.shared
#else
        let ncKit = NextcloudKit()
#endif
        // Now we call the function we want to test; it will use the mock session and request and return the mock data
        ncKit.getLoginFlowV2(serverUrl: "badUrl") { token, endpoint, login, data, error in
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
