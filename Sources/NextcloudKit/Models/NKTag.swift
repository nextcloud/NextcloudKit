// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NKTag: Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let color: String?

    public init(id: String, name: String, color: String?) {
        self.id = id
        self.name = name
        self.color = color
    }
}
