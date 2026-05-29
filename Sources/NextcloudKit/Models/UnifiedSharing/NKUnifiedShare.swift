// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A unified share returned by `ocs/v2.php/apps/sharing/api/v1/...`.
public final class NKUnifiedShare: Codable {
    public let id: String
    public let owner: NKUnifiedShareOwner
    /// Unix time in milliseconds.
    public let lastUpdated: Int64
    public let state: NKUnifiedShareState
    public let sources: [NKUnifiedShareSource]
    public let recipients: [NKUnifiedShareRecipient]
    public let properties: [NKUnifiedShareProperty]
    public let permissions: [NKUnifiedSharePermission]

    enum CodingKeys: String, CodingKey {
        case id
        case owner
        case lastUpdated = "last_updated"
        case state
        case sources
        case recipients
        case properties
        case permissions
    }

    public init(id: String,
                owner: NKUnifiedShareOwner,
                lastUpdated: Int64,
                state: NKUnifiedShareState,
                sources: [NKUnifiedShareSource],
                recipients: [NKUnifiedShareRecipient],
                properties: [NKUnifiedShareProperty],
                permissions: [NKUnifiedSharePermission]) {
        self.id = id
        self.owner = owner
        self.lastUpdated = lastUpdated
        self.state = state
        self.sources = sources
        self.recipients = recipients
        self.properties = properties
        self.permissions = permissions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.owner = try c.decode(NKUnifiedShareOwner.self, forKey: .owner)
        self.lastUpdated = try c.decode(Int64.self, forKey: .lastUpdated)
        self.state = try c.decode(NKUnifiedShareState.self, forKey: .state)
        self.sources = try c.decode([NKUnifiedShareSource].self, forKey: .sources)
        self.recipients = try c.decode([NKUnifiedShareRecipient].self, forKey: .recipients)
        self.permissions = try c.decode([NKUnifiedSharePermission].self, forKey: .permissions)
        self.properties = try Self.decodeProperties(from: c)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(owner, forKey: .owner)
        try c.encode(lastUpdated, forKey: .lastUpdated)
        try c.encode(state, forKey: .state)
        try c.encode(sources, forKey: .sources)
        try c.encode(recipients, forKey: .recipients)
        try c.encode(permissions, forKey: .permissions)
        try c.encode(properties, forKey: .properties)
    }

    /// Dispatch each `properties` element to the correct subclass based on its `type` discriminator.
    /// Uses two independent unkeyed containers — one to peek, one to decode — so we can read the
    /// `type` of every element without consuming the cursor we actually need for the concrete decode.
    private static func decodeProperties(from c: KeyedDecodingContainer<CodingKeys>) throws -> [NKUnifiedShareProperty] {
        var peek = try c.nestedUnkeyedContainer(forKey: .properties)
        var real = try c.nestedUnkeyedContainer(forKey: .properties)
        var result: [NKUnifiedShareProperty] = []

        while !real.isAtEnd {
            let holder = try peek.decode(TypeHolder.self)
            switch holder.type {
            case .date:
                result.append(try real.decode(NKUnifiedSharePropertyDate.self))
            case .enumeration:
                result.append(try real.decode(NKUnifiedSharePropertyEnum.self))
            case .boolean:
                result.append(try real.decode(NKUnifiedSharePropertyBoolean.self))
            case .password:
                result.append(try real.decode(NKUnifiedSharePropertyPassword.self))
            case .string:
                result.append(try real.decode(NKUnifiedSharePropertyString.self))
            }
        }
        return result
    }

    private struct TypeHolder: Decodable {
        let type: NKUnifiedSharePropertyType
    }
}
