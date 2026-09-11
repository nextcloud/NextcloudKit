// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// An item being shared (file, folder, calendar, contact, …).
public struct NKUnifiedShareSource: Codable, Sendable {
    public let `class`: String
    public let value: String
    public let displayName: String
    public let icon: NKUnifiedShareIcon?

    enum CodingKeys: String, CodingKey {
        case `class`
        case value
        case displayName = "display_name"
        case icon
    }
}
