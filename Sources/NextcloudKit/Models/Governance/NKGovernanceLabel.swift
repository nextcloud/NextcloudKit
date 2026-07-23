// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NKGovernanceLabel: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let priority: Int
    public let description: String
    public let color: String
    public let isAssigned: Bool

    public init(id: String, name: String, priority: Int, description: String, color: String, isAssigned: Bool) {
        self.id = id
        self.name = name
        self.priority = priority
        self.description = description
        self.color = color
        self.isAssigned = isAssigned
    }

    enum CodingKeys: String, CodingKey {
        case id, name, priority, description, color, isAssigned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""

        let rawColor = try container.decodeIfPresent(String.self, forKey: .color) ?? ""
        color = rawColor.isEmpty || rawColor.hasPrefix("#") ? rawColor : "#\(rawColor)"

        isAssigned = try container.decodeIfPresent(Bool.self, forKey: .isAssigned) ?? false
    }
}
