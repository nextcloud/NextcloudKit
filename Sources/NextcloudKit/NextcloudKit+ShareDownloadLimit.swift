// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Foundation
import SwiftyJSON

public extension NextcloudKit {
    private func makeEndpoint(with token: String) -> String {
        "ocs/v2.php/apps/files_downloadlimit/api/v1/\(token)/limit"
    }

    func getDownloadLimit(account: String, token: String, completion: @escaping (NKDownloadLimit?, NKError) -> Void) {
        let endpoint = makeEndpoint(with: token)
        let options = NKRequestOptions()

        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async {
                completion(nil, .urlError)
            }
        }

        nkSession
            .sessionData
            .request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor())
            .validate(statusCode: 200..<300)
            .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                if self.nkCommonInstance.levelLog > 0 {
                    debugPrint(response)
                }

                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)

                    options.queue.async {
                        completion(nil, error)
                    }
                case .success(let jsonData):
                    let json = JSON(jsonData)

                    guard json["ocs"]["meta"]["statuscode"].int == 200 else {
                        let error = NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)

                        options.queue.async {
                            completion(nil, error)
                        }

                        return
                    }

                    let count = json["ocs"]["data"]["count"]
                    let limit = json["ocs"]["data"]["limit"]

                    guard count.type != .null else {
                        options.queue.async {
                            completion(nil, .success)
                        }

                        return
                    }

                    guard limit.type != .null else {
                        options.queue.async {
                            completion(nil, .success)
                        }

                        return
                    }

                    let downloadLimit = NKDownloadLimit(count: count.intValue, limit: limit.intValue, token: token)

                    options.queue.async {
                        completion(downloadLimit, .success)
                    }
                }
            }
    }

    func removeShareDownloadLimit(account: String, token: String, completion: @escaping (_ error: NKError) -> Void) {
        let endpoint = makeEndpoint(with: token)
        let options = NKRequestOptions()

        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async {
                completion(.urlError)
            }
        }

        nkSession
            .sessionData
            .request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor())
            .validate(statusCode: 200..<300)
            .response(queue: self.nkCommonInstance.backgroundQueue) { response in
                if self.nkCommonInstance.levelLog > 0 {
                    debugPrint(response)
                }

                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)

                    options.queue.async {
                        completion(error)
                    }
                case .success:
                    options.queue.async {
                        completion(.success)
                    }
                }
            }
    }

    func setShareDownloadLimit(account: String, token: String, limit: Int, completion: @escaping (_ error: NKError) -> Void) {
        let endpoint = makeEndpoint(with: token)
        let options = NKRequestOptions()
        options.contentType = "application/json"

        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options),
              var urlRequest = try? URLRequest(url: url, method: .put, headers: headers) else {
            return options.queue.async {
                completion(.urlError)
            }
        }

        urlRequest.httpBody = try? JSONEncoder().encode([
            "limit": limit
        ])

        nkSession
            .sessionData
            .request(urlRequest, interceptor: NKInterceptor())
            .validate(statusCode: 200..<300)
            .response(queue: self.nkCommonInstance.backgroundQueue) { response in
                if self.nkCommonInstance.levelLog > 0 {
                    debugPrint(response)
                }

                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)

                    options.queue.async {
                        completion(error)
                    }
                case .success:
                    options.queue.async {
                        completion(.success)
                    }
                }
            }
    }
}
