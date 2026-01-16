// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

public struct NKClientIntegrationUIResponse: Codable {
    public let ocs: OCSContainer
}

public struct OCSContainer: Codable {
    public let meta: Meta
    public let data: ResponseData
}

public struct Meta: Codable {
    public let status: String
    public let statuscode: Int
    public let message: String
}

public struct ResponseData: Codable {
//    public let version: String
    public let tooltip: String?
    public let root: RootContainer?
}

public struct RootContainer: Codable {
    public let orientation: String
    public let rows: [Row]
}

public struct Row: Codable {
    public let children: [Child]
}

public struct Child: Codable {
    public let element: String
    public let text: String
    public let url: String
}
