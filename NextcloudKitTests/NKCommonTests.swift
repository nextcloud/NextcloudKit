//
//  NKCommonTests.swift
//  NextcloudKit
//
//  Created by Claudio Cambra on 17/4/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  Author Claudio Cambra <claudio.cambra@nextcloud.com>
//
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

final class NKCommonTests: XCTestCase {
    let nkCommon = NextcloudKit.shared.nkCommonInstance

    let testUser = "testUser"
    let testUserId = "testUser"
    let testPassword = "testPassword"
    let testUrlBase = "https://test.nextcloud.com"
    let testUserAgent = "TestAgent"
    let testNcVersion = 26
    let testDelegate: (any NKCommonDelegate)? = nil

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        NextcloudKit.shared.setup(user: testUser,
                                  userId: testUserId,
                                  password: testPassword,
                                  urlBase: testUrlBase,
                                  userAgent: testUserAgent,
                                  nextcloudVersion: testNcVersion,
                                  delegate: testDelegate)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        NextcloudKit.shared.setup(user: "",
                                  userId: "",
                                  password: "",
                                  urlBase: "",
                                  userAgent: "",
                                  nextcloudVersion: 0,
                                  delegate: nil)
    }

    func testBasicData() {
        XCTAssert(nkCommon.user == testUser)
        XCTAssert(nkCommon.userId == testUserId)
        XCTAssert(nkCommon.password == testPassword)
        XCTAssert(nkCommon.urlBase == testUrlBase)
        XCTAssert(nkCommon.userAgent == testUserAgent)
        XCTAssert(nkCommon.nextcloudVersion == testNcVersion)
    }
}
