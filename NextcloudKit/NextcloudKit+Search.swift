//
//  NextcloudKit+Search.swift
//  NextcloudKit
//
//  Created by Henrik Storch on 2022.

//  Copyright © 2022 Henrik Storch. All rights reserved.
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
    public func unifiedSearch(
        term: String,
        options: NKRequestOptions = NKRequestOptions(),
        timeout: TimeInterval = 30,
        timeoutProvider: TimeInterval = 60,
        filter: @escaping (NKSearchProvider) -> Bool = { _ in true },
        request: @escaping (DataRequest?) -> Void,
        providers: @escaping ([NKSearchProvider]?) -> Void,
        update: @escaping (NKSearchResult?, _ provider: NKSearchProvider, _ error: NKError) -> Void,
        completion: @escaping (_ error: NKError) -> Void) {

            let endpoint = "ocs/v2.php/search/providers?format=json"
            guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
                return completion(.urlError)
            }
            let method = HTTPMethod(rawValue: "GET")
            let headers = NKCommon.shared.getStandardHeaders(options: options)

            let requestUnifiedSearch = sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
                debugPrint(response)

                switch response.result {
                case .success(let json):
                    let json = JSON(json)
                    let providerData = json["ocs"]["data"]
                    guard let allProvider = NKSearchProvider.factory(jsonArray: providerData) else {
                        return completion(NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode))
                    }

                    providers(allProvider)
                    
                    let filteredProviders = allProvider.filter(filter)
                    let group = DispatchGroup()

                    for provider in filteredProviders {
                        group.enter()
                        let requestSearchProvider = self.searchProvider(provider.id, term: term, options: options, timeout: timeoutProvider) { partial, error in
                            update(partial, provider, error)
                            group.leave()
                        }
                        request(requestSearchProvider)
                    }

                    group.notify(queue: options.queue) {
                        completion(.success)
                    }
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response)
                    return completion(error)
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
                               term: String,
                               limit: Int? = nil,
                               cursor: Int? = nil,
                               options: NKRequestOptions = NKRequestOptions(),
                               timeout: TimeInterval = 60,
                               completion: @escaping (NKSearchResult?, _ error: NKError) -> Void) -> DataRequest? {

        guard let term = term.urlEncoded else {
            completion(nil, .urlError)
            return nil
        }
        var endpoint = "ocs/v2.php/search/providers/\(id)/search?format=json&term=\(term)"
        if let limit = limit {
            endpoint += "&limit=\(limit)"
        }
        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }
        
        guard let url = NKCommon.shared.createStandardUrl(
            serverUrl: NKCommon.shared.urlBase,
            endpoint: endpoint)
        else {
            completion(nil, .urlError)
            return nil
        }

        let method = HTTPMethod(rawValue: "GET")
        let headers = NKCommon.shared.getStandardHeaders(options: options)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            completion(nil, NKError(error: error))
            return nil
        }

        let requestSearchProvider = sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            switch response.result {
            case .success(let json):
                let json = JSON(json)
                let searchData = json["ocs"]["data"]
                guard let searchResult = NKSearchResult(json: searchData, id: id) else {
                    return completion(nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode))
                }
                completion(searchResult, .success)
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                return completion(nil, error)
            }
        }

        return requestSearchProvider
    }
}
