//
//  File.swift
//  NextcloudKit
//
//  Created by Milen Pivchev on 10.07.25.
//

import Foundation
//
//public struct NKDeclarativeUI {
//    public struct ContextMenu: Codable {
//        let title: String
//        let url: String
//    }
//}

public struct DeclarativeUI: Codable {
    public let contextMenu: [ContextMenuItem]

    enum CodingKeys: String, CodingKey {
        case contextMenu = "context-menu"
    }
}

public struct ContextMenuItem: Codable {
    public let title: String
    public let endpoint: String

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        title = try container.decode(String.self)
        endpoint = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(title)
        try container.encode(endpoint)
    }
}
