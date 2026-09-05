// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A selectable permission preset advertised by the sharing capability.
public struct NKUnifiedSharePermissionPreset: Codable, Sendable {
    public let `class`: String
    public let displayName: String
    public let hint: String?

    public init(class: String, displayName: String, hint: String? = nil) {
        self.class = `class`
        self.displayName = displayName
        self.hint = hint
    }

    enum CodingKeys: String, CodingKey {
        case `class`
        case displayName = "display_name"
        case hint
    }
}
