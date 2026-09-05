// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A source type advertised by the sharing capability.
public struct NKUnifiedShareSourceType: Codable, Sendable {
    public let `class`: String

    public init(class: String) {
        self.class = `class`
    }

    enum CodingKeys: String, CodingKey {
        case `class`
    }
}
