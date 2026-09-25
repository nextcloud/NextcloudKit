// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Owner of a unified share.
public struct NKUnifiedShareOwner: Codable, Sendable {
    public let userId: String
    public let instance: String?
    public let displayName: String
    public let icon: NKUnifiedShareIcon

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case instance
        case displayName = "display_name"
        case icon
    }
}
