// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A toggleable permission on a unified share (can view / can edit / can comment / …).
public struct NKUnifiedSharePermission: Codable, Sendable {
    public let `class`: String
    public let sourceClass: String?
    public let displayName: String
    public let hint: String?
    public let priority: Int
    /// Class identifiers of the permission presets this permission belongs to.
    public let presets: [String]
    public let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case `class`
        case sourceClass = "source_class"
        case displayName = "display_name"
        case hint
        case priority
        case presets
        case enabled
    }
}
