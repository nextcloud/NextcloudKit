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
    public let version: Double
    public let contextMenu: [ContextMenuAction]

    enum CodingKeys: String, CodingKey {
        case version
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

//    func asRequest(user: String, password: String, userAgent: String? = nil,
//                   options: NKRequestOptions = NKRequestOptions(),
//                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
//                   completion: @escaping (_ token: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) async {
//
//        // Convert string method to Alamofire HTTPMethod
//        let httpMethod = HTTPMethod(rawValue: method.uppercased())
//
//        // Map params/bodyParams arrays into key/value (example: fileId → dummy value)
//        var queryParams: [String: Any]? = nil
//        if let params = params {
//            queryParams = Dictionary(uniqueKeysWithValues: params.map { ($0, "SOME_VALUE") })
//        }
//
//        var body: [String: Any]? = nil
//        if let bodyParams = bodyParams {
//            body = Dictionary(uniqueKeysWithValues: bodyParams.map { ($0, "SOME_BODY_VALUE") })
//        }
//
//        await NextcloudKit.shared.sendRequestAsync(fullUrl: url,
//                                                   method: httpMethod,
//                                                   user: user,
//                                                   password: password,
//                                                   userAgent: userAgent,
//                                                   params: queryParams,
//                                                   bodyParams: body,
//                                                   options: options,
//                                                   taskHandler: taskHandler)
//    }
}

