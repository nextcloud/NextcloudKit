// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

public struct NKClientIntegration: Codable {
    public let apps: [String: AppContext]

    public init(from decoder: Decoder) throws {
         let container = try decoder.container(keyedBy: DynamicKey.self)

         var dict: [String: AppContext] = [:]
         for key in container.allKeys {
             let value = try container.decode(AppContext.self, forKey: key)
             dict[key.stringValue] = value
         }
         self.apps = dict
     }

    public func encode(to encoder: Encoder) throws {
         var container = encoder.container(keyedBy: DynamicKey.self)
         for (key, value) in apps {
             try container.encode(value, forKey: DynamicKey(stringValue: key)!)
         }
     }

    public enum Params: String {
        case fileId = "fileId"
        case filePath = "filePath"
    }
 }

 struct DynamicKey: CodingKey {
     var stringValue: String
     var intValue: Int? { nil }
     init?(stringValue: String) { self.stringValue = stringValue }
     init?(intValue: Int) { return nil }
 }

public struct AppContext: Codable {
//    public let version: Double
    public let contextMenu: [ContextMenuAction]

    enum CodingKeys: String, CodingKey {
//        case version
        case contextMenu = "context-menu"
    }
}

public struct ContextMenuAction: Codable {
    public let name: String
    public let url: String
    public let method: String
    public let mimetypeFilters: String?
    public let params: [String: String]?
    public let icon: String?

    enum CodingKeys: String, CodingKey {
        case name, url, method, icon, params
        case mimetypeFilters = "mimetype_filters"
    }
}

