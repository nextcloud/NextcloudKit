// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import NextcloudKit

class BaseIntegrationXCTestCase: BaseXCTestCase {
    internal var randomInt: Int {
        get {
            return Int.random(in: 1000...Int.max)
        }
    }
}
