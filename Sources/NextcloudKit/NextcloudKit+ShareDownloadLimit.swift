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

    /// Retrieves the current download limit for a shared file based on its public share token.
    ///
    /// Parameters:
    /// - account: The Nextcloud account identifier.
    /// - token: The public share token associated with the file or folder.
    /// - completion: A closure returning:
    ///   - NKDownloadLimit?: The current download limit information, or `nil` if not available.
    ///   - NKError: An object representing success or error during the request.
    func getDownloadLimit(account: String, token: String, completion: @escaping (NKDownloadLimit?, NKError) -> Void) {
        let endpoint = makeEndpoint(with: token)
        let options = NKRequestOptions()

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async {
                completion(nil, .urlError)
            }
        }

        nkSession
            .sessionData
            .request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Retrieves the current download limit for a shared file using its public token.
    ///
    /// Parameters:
    /// - account: The account associated with the Nextcloud session.
    /// - token: The public share token used to identify the shared file.
    ///
    /// Returns: A tuple containing:
    /// - downloadLimit: The current NKDownloadLimit object if available.
    /// - error: The NKError representing success or failure of the request.
    func getDownloadLimitAsync(account: String, token: String) async -> (
        downloadLimit: NKDownloadLimit?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getDownloadLimit(account: account, token: token) { limit, error in
                continuation.resume(returning: (
                    downloadLimit: limit,
                    error: error
                ))
            }
        }
    }

    /// Removes the download limit for a shared file using its public share token.
    ///
    /// Parameters:
    /// - account: The Nextcloud account identifier.
    /// - token: The public share token associated with the file or folder.
    /// - completion: A closure returning:
    ///   - NKError: An object representing the success or failure of the request.
    func removeShareDownloadLimit(account: String, token: String, completion: @escaping (_ error: NKError) -> Void) {
        let endpoint = makeEndpoint(with: token)
        let options = NKRequestOptions()

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async {
                completion(.urlError)
            }
        }

        nkSession
            .sessionData
            .request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously removes the download limit for a public shared file or folder.
    ///
    /// Parameters:
    /// - account: The Nextcloud account used for the request.
    /// - token: The public token representing the shared resource.
    ///
    /// Returns: An NKError that indicates the outcome of the operation.
    func removeShareDownloadLimitAsync(account: String, token: String) async -> NKError {
        await withCheckedContinuation { continuation in
            removeShareDownloadLimit(account: account, token: token) { error in
                continuation.resume(returning: error)
            }
        }
    }

    /// Sets a download limit for a public shared file or folder.
    ///
    /// Parameters:
    /// - account: The Nextcloud account associated with the request.
    /// - token: The public share token identifying the shared resource.
    /// - limit: The new download limit to be set.
    /// - completion: A closure returning:
    ///   - error: An NKError representing the success or failure of the operation.
    func setShareDownloadLimit(account: String, token: String, limit: Int, completion: @escaping (_ error: NKError) -> Void) {
        let endpoint = makeEndpoint(with: token)
        let options = NKRequestOptions()
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json"),
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
            .request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously sets a download limit for a public shared file or folder.
    ///
    /// Parameters:
    /// - account: The Nextcloud account used for the request.
    /// - token: The public share token of the resource.
    /// - limit: The maximum number of downloads to allow.
    ///
    /// Returns: An NKError indicating whether the operation was successful.
    func setShareDownloadLimitAsync(account: String, token: String, limit: Int) async -> NKError {
        await withCheckedContinuation { continuation in
            setShareDownloadLimit(account: account, token: token, limit: limit) { error in
                continuation.resume(returning: error)
            }
        }
    }
}
