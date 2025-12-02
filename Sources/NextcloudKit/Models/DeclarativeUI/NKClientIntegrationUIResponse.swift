// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

public struct NKClientIntegrationUIResponse: Codable {
    let version: Double
    let root: RootContainer
}

public struct RootContainer: Codable {
    let orientation: String
    let rows: [Row]
}

public struct Row: Codable {
    let children: [Child]
}

public struct Child: Codable {
    let element: String
    let text: String?
    let url: String?
}
