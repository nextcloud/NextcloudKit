// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A toggleable permission on a unified share (can view / can edit / can comment / …).
public struct NKUnifiedSharePermission: Codable, Sendable {
    public let `class`: String
    public let displayName: String
    public let hint: String?
    public let category: String?
    public let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case `class`
        case displayName = "display_name"
        case hint
        case category
        case enabled
    }
}
