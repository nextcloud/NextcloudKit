//
// SPDX-FileCopyrightText: 2023 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//

import XCTest
@testable import NextcloudKit

class BaseIntegrationXCTestCase: XCTestCase {
    internal let baseUrl = EnvVars.testServerUrl
    internal let user = EnvVars.testUser
    internal let userId = EnvVars.testUser
    internal let password = EnvVars.testAppPassword
    internal lazy var account = "\(userId) \(baseUrl)"
    internal var randomInt: Int {
        get {
            return Int.random(in: 1000...Int.max)
        }
    }
}
