// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A recipient (user, group, federated user, public link, …) on a unified share.
public struct NKUnifiedShareRecipient: Codable, Sendable {
    public let `class`: String
    public let value: String
    public let instance: String?
    public let displayName: String
    public let icon: NKUnifiedShareIcon?

    enum CodingKeys: String, CodingKey {
        case `class`
        case value
        case instance
        case displayName = "display_name"
        case icon
    }
}
