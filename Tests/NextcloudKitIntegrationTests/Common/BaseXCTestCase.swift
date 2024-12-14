// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Foundation
import UIKit
import Alamofire
import NextcloudKit

class BaseXCTestCase: XCTestCase {
    var appToken = ""

    func setupAppToken() {
        let expectation = expectation(description: "Should get app token")

        NextcloudKit.shared.getAppPassword(url: TestConstants.server, user: TestConstants.username, password: TestConstants.password) { token, _, error in
            XCTAssertEqual(error.errorCode, 0)
            XCTAssertNotNil(token)

            guard let token else { return XCTFail() }
            
            self.appToken = token
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: TestConstants.timeoutLong)
    }

    override func setUpWithError() throws {
        setupAppToken()
    }
}
