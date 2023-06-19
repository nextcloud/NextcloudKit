//
//  NextcloudKit+Search.swift
//  NextcloudKit
//
//  Created by Henrik Storch on 2022.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import Alamofire
import SwiftyJSON

extension NextcloudKit {

    /// Available NC >= 20
    /// Search many different datasources in the cloud and combine them into one result.
    ///
    /// - Warning: Providers are requested concurrently. Not filtering will result in a high network load.
    ///
    /// - SeeAlso:
    ///  [Nextcloud Search API](https://docs.nextcloud.com/server/latest/developer_manual/digging_deeper/search.html)
    ///
    /// - Parameters:
    ///   - term: The search term
    ///   - options: Additional request options
    ///   - filter: Filter search provider that should be searched. Default is all available provider..
    ///   - update: Callback, notifying that a search provider return its result. Does not include previous results.
    ///   - completion: Callback, notifying that all search providers have been searched. The search is done. Includes all search results.
    public func unifiedSearch(term: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              timeout: TimeInterval = 30,
                              timeoutProvider: TimeInterval = 60,
                              filter: @escaping (NKSearchProvider) -> Bool = { _ in true },
                              request: @escaping (DataRequest?) -> Void,
                              providers: @escaping (_ account: String, _ searchProviders: [NKSearchProvider]?) -> Void,
                              update: @escaping (_ account: String, _ searchResult: NKSearchResult?, _ provider: NKSearchProvider, _ error: NKError) -> Void,
                              completion: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/search/providers"

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return completion(account, nil, .urlError)
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        let requestUnifiedSearch = sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .success(let jsonData):
                let json = JSON(jsonData)
                let providerData = json["ocs"]["data"]
                guard let allProvider = NKSearchProvider.factory(jsonArray: providerData) else {
                    return completion(account, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode))
                }

                providers(account, allProvider)

                let filteredProviders = allProvider.filter(filter)
                let group = DispatchGroup()

                for provider in filteredProviders {
                    group.enter()
                    let requestSearchProvider = self.searchProvider(provider.id, account: account, term: term, options: options, timeout: timeoutProvider) { account, partial, _, error in
                        update(account, partial, provider, error)
                        group.leave()
                    }
                    request(requestSearchProvider)
                }

                group.notify(queue: options.queue) {
                    completion(account, jsonData, .success)
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                return completion(account, nil, error)
            }
        }
        request(requestUnifiedSearch)
    }

    /// Available NC >= 20
    /// Search many different datasources in the cloud and combine them into one result.
    ///
    /// - SeeAlso:
    ///  [Nextcloud Search API](https://docs.nextcloud.com/server/latest/developer_manual/digging_deeper/search.html)
    ///
    /// - Parameters:
    ///   - id: provider id
    ///   - term: The search term
    ///   - limit: limit (pagination)
    ///   - cursor: cursor (pagination)
    ///   - options: Additional request options
    ///   - timeout: Filter search provider that should be searched. Default is all available provider..
    ///   - update: Callback, notifying that a search provider return its result. Does not include previous results.
    ///   - completion: Callback, notifying that all search results.
    @discardableResult
    public func searchProvider(_ id: String,
                               account: String,
                               term: String,
                               limit: Int? = nil,
                               cursor: Int? = nil,
                               options: NKRequestOptions = NKRequestOptions(),
                               timeout: TimeInterval = 60,
                               completion: @escaping (_ accoun: String, NKSearchResult?, _ data: Data?, _ error: NKError) -> Void) -> DataRequest? {

        let urlBase = self.nkCommonInstance.urlBase

        guard let term = term.urlEncoded else {
            completion(account, nil, nil, .urlError)
            return nil
        }

        var endpoint = "ocs/v2.php/search/providers/\(id)/search?term=\(term)"

        if let limit = limit {
            endpoint += "&limit=\(limit)"
        }

        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }

        guard let url = self.nkCommonInstance.createStandardUrl(
            serverUrl: urlBase,
            endpoint: endpoint)
        else {
            completion(account, nil, nil, .urlError)
            return nil
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .get, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            completion(account, nil, nil, NKError(error: error))
            return nil
        }

        let requestSearchProvider = sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)
            switch response.result {
            case .success(let jsonData):
                let json = JSON(jsonData)
                let searchData = json["ocs"]["data"]
                guard let searchResult = NKSearchResult(json: searchData, id: id) else {
                    return completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode))
                }
                completion(account, searchResult, jsonData, .success)
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                return completion(account, nil, nil, error)
            }
        }

        return requestSearchProvider
    }
}

@objc public class NKSearchResult: NSObject {

    @objc public let id: String
    @objc public let name: String
    @objc public let isPaginated: Bool
    @objc public let entries: [NKSearchEntry]
    public let cursor: Int?

    init?(json: JSON, id: String) {
        guard let isPaginated = json["isPaginated"].bool,
              let name = json["name"].string,
              let entries = NKSearchEntry.factory(jsonArray: json["entries"])
        else { return nil }
        self.id = id
        self.cursor = json["cursor"].int
        self.name = name
        self.isPaginated = isPaginated
        self.entries = entries
    }
}

@objc public class NKSearchEntry: NSObject {

    @objc public let thumbnailURL: String
    @objc public let title, subline: String
    @objc public let resourceURL: String
    @objc public let icon: String
    @objc public let rounded: Bool
    @objc public let attributes: [String: Any]?

    public var fileId: Int? {
        guard let fileAttribute = attributes?["fileId"] as? String else { return nil }
        return Int(fileAttribute)
    }

    @objc public var filePath: String? {
        attributes?["path"] as? String
    }

    init?(json: JSON) {
        guard let thumbnailURL = json["thumbnailUrl"].string,
              let title = json["title"].string,
              let subline = json["subline"].string,
              let resourceURL = json["resourceUrl"].string,
              let icon = json["icon"].string,
              let rounded = json["rounded"].bool
        else { return nil }

        self.thumbnailURL = thumbnailURL
        self.title = title
        self.subline = subline
        self.resourceURL = resourceURL
        self.icon = icon
        self.rounded = rounded
        self.attributes = json["attributes"].dictionaryObject
    }

    static func factory(jsonArray: JSON) -> [NKSearchEntry]? {
        guard let allProvider = jsonArray.array else { return nil }
        return allProvider.compactMap(NKSearchEntry.init)
    }
}

@objc public class NKSearchProvider: NSObject {

    init?(json: JSON) {
        guard let id = json["id"].string,
              let name = json["name"].string,
              let order = json["order"].int
        else { return nil }
        self.id = id
        self.name = name
        self.order = order
    }

    @objc public let id, name: String
    @objc public let order: Int

    static func factory(jsonArray: JSON) -> [NKSearchProvider]? {
        guard let allProvider = jsonArray.array else { return nil }
        return allProvider.compactMap(NKSearchProvider.init)
    }
}
