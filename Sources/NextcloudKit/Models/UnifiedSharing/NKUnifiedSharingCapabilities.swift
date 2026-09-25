// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The `sharing` block of the server capabilities, describing unified-sharing support.
public struct NKUnifiedSharingCapabilities: Codable, Sendable {
    public let apiVersions: [String]
    public let sourceTypes: [NKUnifiedShareSourceType]
    public let permissionPresets: [NKUnifiedSharePermissionPreset]

    public init(apiVersions: [String], sourceTypes: [NKUnifiedShareSourceType], permissionPresets: [NKUnifiedSharePermissionPreset]) {
        self.apiVersions = apiVersions
        self.sourceTypes = sourceTypes
        self.permissionPresets = permissionPresets
    }

    enum CodingKeys: String, CodingKey {
        case apiVersions = "api_versions"
        case sourceTypes = "source_types"
        case permissionPresets = "permission_presets"
    }
}
