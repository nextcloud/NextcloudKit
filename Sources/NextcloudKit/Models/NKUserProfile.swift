// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKUserProfile: NSObject {
    public var address = ""
    public var backend = ""
    public var backendCapabilitiesSetDisplayName: Bool = false
    public var backendCapabilitiesSetPassword: Bool = false
    public var displayName = ""
    public var email = ""
    public var enabled: Bool = false
    public var groups: [String] = []
    public var language = ""
    public var lastLogin: Int64 = 0
    public var locale = ""
    public var organisation = ""
    public var phone = ""
    public var quota: Int64 = 0
    public var quotaFree: Int64 = 0
    public var quotaRelative: Double = 0
    public var quotaTotal: Int64 = 0
    public var quotaUsed: Int64 = 0
    public var storageLocation = ""
    public var subadmin: [String] = []
    public var twitter = ""
    public var userId = ""
    public var website = ""
}
