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
    public let scopes: [NKGovernanceLabelScope]

    public init(id: String, name: String, priority: Int, description: String, color: String, scopes: [NKGovernanceLabelScope]) {
        self.id = id
        self.name = name
        self.priority = priority
        self.description = description
        self.color = color
        self.scopes = scopes
    }

    enum CodingKeys: String, CodingKey {
        case id, name, priority, description, color, scopes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        priority = try container.decode(Int.self, forKey: .priority)
        description = try container.decode(String.self, forKey: .description)
        color = try container.decode(String.self, forKey: .color)
        // Tolerate unknown scope values rather than failing the whole decode.
        let rawScopes = try container.decodeIfPresent([String].self, forKey: .scopes) ?? []
        scopes = rawScopes.compactMap(NKGovernanceLabelScope.init(rawValue:))
    }
}
