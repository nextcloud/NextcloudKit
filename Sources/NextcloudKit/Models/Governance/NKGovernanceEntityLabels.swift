// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NKGovernanceEntityLabels: Codable, Sendable, Equatable, Hashable {
    public let sensitivity: NKGovernanceLabel?
    public let retention: [NKGovernanceLabel]

    public init(sensitivity: NKGovernanceLabel?, retention: [NKGovernanceLabel]) {
        self.sensitivity = sensitivity
        self.retention = retention
    }

    enum CodingKeys: String, CodingKey {
        case sensitivity, retention
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sensitivity = try container.decodeIfPresent(NKGovernanceLabel.self, forKey: .sensitivity)
        retention = try container.decodeIfPresent([NKGovernanceLabel].self, forKey: .retention) ?? []
    }
}
