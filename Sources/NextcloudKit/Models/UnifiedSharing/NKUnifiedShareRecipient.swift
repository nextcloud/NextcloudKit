// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
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

    enum CodingKeys: String, CodingKey {
        case `class`
        case value
        case instance
        case displayName = "display_name"
        case icon
        case secret
        case initiator
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
