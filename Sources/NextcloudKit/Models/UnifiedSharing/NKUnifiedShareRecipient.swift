// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A recipient (user, group, federated user, public link, …) on a unified share.
public struct NKUnifiedShareRecipient: Codable, Sendable {
    public let `class`: String
    public let value: String
    public let instance: String?
    public let displayName: String
    public let icon: NKUnifiedShareIcon?
    public let secret: Secret
    public let initiator: NKUnifiedShareOwner?
    public let permissions: [NKUnifiedSharePermission]

    enum CodingKeys: String, CodingKey {
        case `class`
        case value
        case instance
        case displayName = "display_name"
        case icon
        case secret
        case initiator
        case permissions
    }

    public init(`class`: String,
                value: String,
                instance: String?,
                displayName: String,
                icon: NKUnifiedShareIcon?,
                secret: Secret,
                initiator: NKUnifiedShareOwner?,
                permissions: [NKUnifiedSharePermission] = []) {
        self.class = `class`
        self.value = value
        self.instance = instance
        self.displayName = displayName
        self.icon = icon
        self.secret = secret
        self.initiator = initiator
        self.permissions = permissions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.class = try container.decode(String.self, forKey: .class)
        self.value = try container.decode(String.self, forKey: .value)
        self.instance = try container.decodeIfPresent(String.self, forKey: .instance)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.icon = try container.decodeIfPresent(NKUnifiedShareIcon.self, forKey: .icon)
        self.secret = try container.decode(Secret.self, forKey: .secret)
        self.initiator = try container.decodeIfPresent(NKUnifiedShareOwner.self, forKey: .initiator)
        self.permissions = try container.decodeIfPresent([NKUnifiedSharePermission].self, forKey: .permissions) ?? []
    }

    /// A recipient's secret; `url` carries the public link when present.
    public struct Secret: Codable, Sendable {
        public let updatable: Bool
        public let value: String?
        public let url: String?

        public init(updatable: Bool, value: String? = nil, url: String? = nil) {
            self.updatable = updatable
            self.value = value
            self.url = url
        }
    }
}
