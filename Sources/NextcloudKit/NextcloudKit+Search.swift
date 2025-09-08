// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Storch
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Available NC >= 20
    /// Performs a unified search using multiple providers and returns results asynchronously.
    ///
    /// - Parameters:
    ///   - term: The search term to query.
    ///   - timeout: The individual request timeout per provider.
    ///   - timeoutProvider: The maximum time allowed for each provider before being cancelled.
    ///   - account: The Nextcloud account performing the search.
    ///   - options: Optional configuration for the request (headers, queue, etc.).
    ///   - filter: A closure to filter which `NKSearchProvider` are enabled.
    ///   - request: Callback to access and inspect the underlying `DataRequest?`.
    ///   - taskHandler: Callback triggered when a `URLSessionTask` is created.
    ///   - providers: Callback providing the list of providers that will be queried.
    ///   - update: Called for every result update from a provider.
    ///   - completion: Called when all providers are finished, returns the response and status.
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
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

    /// Asynchronously performs a unified search and returns the final search response.
    ///
    /// - Parameters:
    ///   - term: The string to search for.
    ///   - timeout: Per-provider timeout in seconds.
    ///   - timeoutProvider: Overall timeout for a provider.
    ///   - account: The account used to authenticate the request.
    ///   - options: Optional parameters for the search.
    ///   - filter: Closure to filter the search providers.
    ///   - request: Callback with the underlying `DataRequest?`.
    ///   - taskHandler: Monitors the task creation.
    ///   - providers: Callback that reports which providers are used.
    ///   - update: Callback triggered as results come in from providers.
    /// - Returns: Final completion with account, raw response data, and NKError.
    func unifiedSearchAsync(term: String,
                            timeout: TimeInterval = 30,
                            timeoutProvider: TimeInterval = 60,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            filter: @escaping (NKSearchProvider) -> Bool = { _ in true },
                            request: @escaping (DataRequest?) -> Void,
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            providers: @escaping (_ account: String, _ searchProviders: [NKSearchProvider]?) -> Void,
                            update: @escaping (_ account: String, _ searchResult: NKSearchResult?, _ provider: NKSearchProvider, _ error: NKError) -> Void
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            unifiedSearch(term: term,
                          timeout: timeout,
                          timeoutProvider: timeoutProvider,
                          account: account,
                          options: options,
                          filter: filter,
                          request: request,
                          taskHandler: taskHandler,
                          providers: providers,
                          update: update) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Available NC >= 20
    /// Performs a search using a specified provider with pagination and timeout support.
    ///
    /// - Parameters:
    ///   - id: The identifier of the search provider to use.
    ///   - term: The search term.
    ///   - limit: Optional maximum number of results to return.
    ///   - cursor: Optional pagination cursor for subsequent requests.
    ///   - timeout: The timeout interval for the search request.
    ///   - account: The Nextcloud account performing the search.
    ///   - options: Optional request configuration such as headers and queue.
    ///   - taskHandler: Callback to observe the underlying URLSessionTask.
    ///   - completion: Completion handler returning the account, search results, raw response, and NKError.
    ///
    /// - Returns: The underlying DataRequest object if the request was started, otherwise nil.
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
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint)
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

    /// Asynchronously performs a search request using the specified provider.
    ///
    /// - Parameters:
    ///   - id: The identifier of the search provider to use.
    ///   - term: The search query string.
    ///   - limit: Optional limit for number of results.
    ///   - cursor: Optional pagination cursor.
    ///   - timeout: The timeout for the request.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional configuration options for the request.
    ///   - taskHandler: Callback to observe the created task.
    ///
    /// - Returns: A tuple containing the account, search result, response data, and error.
    func searchProviderAsync(_ id: String,
                             term: String,
                             limit: Int? = nil,
                             cursor: Int? = nil,
                             timeout: TimeInterval = 60,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        searchResult: NKSearchResult?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            _ = searchProvider(id,
                               term: term,
                               limit: limit,
                               cursor: cursor,
                               timeout: timeout,
                               account: account,
                               options: options,
                               taskHandler: taskHandler) { account, result, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    searchResult: result,
                    responseData: responseData,
                    error: error
                ))
            }
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
