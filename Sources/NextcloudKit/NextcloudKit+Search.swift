// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Storch
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
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
    func unifiedSearch(term: String,
                       timeout: TimeInterval = 30,
                       timeoutProvider: TimeInterval = 60,
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       filter: @escaping (NKSearchProvider) -> Bool = { _ in true },
                       request: @escaping (DataRequest?) -> Void,
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       providers: @escaping (_ account: String, _ searchProviders: [NKSearchProvider]?) -> Void,
                       update: @escaping (_ account: String, _ searchResult: NKSearchResult?, _ provider: NKSearchProvider, _ error: NKError) -> Void,
                       completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/search/providers"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        let requestUnifiedSearch = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .success(let jsonData):
                let json = JSON(jsonData)
                let providerData = json["ocs"]["data"]
                guard let allProvider = NKSearchProvider.factory(jsonArray: providerData) else {
                    return completion(account, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode))
                }
                providers(account, allProvider)

                let filteredProviders = allProvider.filter(filter)
                let group = DispatchGroup()

                for provider in filteredProviders {
                    group.enter()
                    let requestSearchProvider = self.searchProvider(provider.id, term: term, timeout: timeoutProvider, account: account, options: options) { account, partial, _, error in
                        update(account, partial, provider, error)
                        group.leave()
                    }
                    request(requestSearchProvider)
                }

                group.notify(queue: options.queue) {
                    completion(account, response, .success)
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                return completion(account, response, error)
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
    func searchProvider(_ id: String,
                        term: String,
                        limit: Int? = nil,
                        cursor: Int? = nil,
                        timeout: TimeInterval = 60,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, NKSearchResult?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) -> DataRequest? {
        guard let term = term.urlEncoded,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
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
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options)
        else {
            completion(account, nil, nil, .urlError)
            return nil
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: .get, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            completion(account, nil, nil, NKError(error: error))
            return nil
        }

        let requestSearchProvider = nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .success(let jsonData):
                let json = JSON(jsonData)
                let searchData = json["ocs"]["data"]
                guard let searchResult = NKSearchResult(json: searchData, id: id) else {
                    return completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode))
                }
                completion(account, searchResult, response, .success)
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                return completion(account, nil, response, error)
            }
        }

        return requestSearchProvider
    }
}

public class NKSearchResult: NSObject {
    public let id: String
    public let name: String
    public let isPaginated: Bool
    public let entries: [NKSearchEntry]
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

public class NKSearchEntry: NSObject {
    public let thumbnailURL: String
    public let title, subline: String
    public let resourceURL: String
    public let icon: String
    public let rounded: Bool
    public let attributes: [String: Any]?
    public var fileId: Int? {
        guard let fileAttribute = attributes?["fileId"] as? String else { return nil }
        return Int(fileAttribute)
    }
    public var filePath: String? {
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

public class NKSearchProvider: NSObject {
    public let id, name: String
    public let order: Int

    init?(json: JSON) {
        guard let id = json["id"].string,
              let name = json["name"].string,
              let order = json["order"].int
        else { return nil }
        self.id = id
        self.name = name
        self.order = order
    }

    static func factory(jsonArray: JSON) -> [NKSearchProvider]? {
        guard let allProvider = jsonArray.array else { return nil }
        return allProvider.compactMap(NKSearchProvider.init)
    }
}
