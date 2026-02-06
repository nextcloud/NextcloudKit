// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Storch
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Performs a unified search using multiple providers and returns results asynchronously.
    ///
    /// - Parameters:
    ///   - timeout: The individual request timeout per provider.
    ///   - account: The Nextcloud account performing the search.
    ///   - options: Optional configuration for the request (headers, queue, etc.).
    ///   - filter: A closure to filter which `NKSearchProvider` are enabled.
    ///   - taskHandler: Callback triggered when a `URLSessionTask` is created.
    ///
    /// - Returns: NKSearchProvider, NKError
    func unifiedSearchProviders(timeout: TimeInterval = 30,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                filter: @escaping (NKSearchProvider) -> Bool = { _ in true },
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (providers: [NKSearchProvider]?, error: NKError) {
        let endpoint = "ocs/v2.php/search/providers"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (nil, .urlError)
        }

        let request = nkSession.sessionData
            .request(url, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
        let response = await request.serializingData().response

        switch response.result {
        case .success(let jsonData):
            let json = JSON(jsonData)
            let providerData = json["ocs"]["data"]
            let providers = NKSearchProvider.factory(jsonArray: providerData)?.filter(filter)

            return(providers, .success)
        case .failure(let error):
            let nkError = NKError(error: error, afResponse: response, responseData: response.data)

            return (nil, nkError)
        }
    }

    /// Performs a search using a specified provider with pagination and timeout support.
    ///
    /// - Parameters:
    ///   - providerId: The identifier of the search provider to use.
    ///   - term: The search term.
    ///   - limit: Optional maximum number of results to return.
    ///   - cursor: Optional pagination cursor for subsequent requests.
    ///   - timeout: The timeout interval for the search request.
    ///   - account: The Nextcloud account performing the search.
    ///   - options: Optional request configuration such as headers and queue.
    ///   - taskHandler: Callback to observe the underlying URLSessionTask.
    ///
    /// - Returns: NKSearchResult, NKError
    func unifiedSearch(providerId: String,
                       term: String,
                       limit: Int? = nil,
                       cursor: Int? = nil,
                       timeout: TimeInterval = 60,
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in })
    async -> (searchResult: NKSearchResult?, error: NKError) {
        guard let term = term.urlEncoded,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return(nil, .urlError)
        }
        var endpoint = "ocs/v2.php/search/providers/\(providerId)/search?term=\(term)"
        if let limit = limit {
            endpoint += "&limit=\(limit)"
        }
        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint)
        else {
            return(nil, .urlError)
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: .get, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            return(nil, NKError(error: error))
        }

        let request = nkSession.sessionData
            .request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
        let response = await request.serializingData().response

        switch response.result {
        case .success(let jsonData):
            let json = JSON(jsonData)
            let searchData = json["ocs"]["data"]
            let searchResult = NKSearchResult(json: searchData, id: providerId)

            return (searchResult, .success)
        case .failure(let error):
            let nkError = NKError(error: error, afResponse: response, responseData: response.data)

            return (nil, nkError)
        }
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

    // Initialize from JSON
    init?(json: JSON) {
        guard let id = json["id"].string,
              let name = json["name"].string,
              let order = json["order"].int
        else { return nil }
        self.id = id
        self.name = name
        self.order = order
    }

    // Classic initializer
    public init(id: String, name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
        super.init()
    }

    static func factory(jsonArray: JSON) -> [NKSearchProvider]? {
        guard let allProvider = jsonArray.array else { return nil }
        return allProvider.compactMap(NKSearchProvider.init)
    }
}
