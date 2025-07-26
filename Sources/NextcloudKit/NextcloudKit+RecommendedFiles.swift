// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Retrieves a list of recommended files from the server.
    ///
    /// Parameters:
    /// - account: The Nextcloud account used to perform the request.
    /// - options: Optional configuration for headers, queue, versioning, etc.
    /// - request: Optional callback to observe or manipulate the underlying DataRequest.
    /// - taskHandler: Callback triggered when the URLSessionTask is created.
    /// - completion: Completion handler returning the account, the list of recommendations,
    ///               the raw response data, and an NKError result.
    func getRecommendedFiles(account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             request: @escaping (DataRequest?) -> Void = { _ in },
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ recommendations: [NKRecommendation]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/recommendations/api/v1/recommendations"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, accept: "application/xml") else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let tosRequest = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .success(let data):
                if let xmlString = String(data: data, encoding: .utf8) {
                    let parser = XMLToRecommendationParser()
                    if let recommendations = parser.parse(xml: xmlString) {
                        options.queue.async { completion(account, recommendations, response, .success) }
                    } else {
                        options.queue.async { completion(account, nil, response, .xmlError) }
                    }
                } else {
                    options.queue.async { completion(account, nil, response, .xmlError) }
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async {
                    completion(account, nil, response, error)
                }
            }
        }
        options.queue.async { request(tosRequest) }
    }

    /// Asynchronously fetches a list of recommended files for the given account.
    ///
    /// - Parameters:
    ///   - account: The Nextcloud account requesting the recommendations.
    ///   - options: Optional configuration for queue, headers, etc.
    ///   - request: Optional callback to capture the DataRequest object.
    ///   - taskHandler: Optional handler for the URLSessionTask.
    /// - Returns: A tuple containing the account, list of recommended files, raw response data, and NKError result.
    func getRecommendedFilesAsync(account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  request: @escaping (DataRequest?) -> Void = { _ in },
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        recommendations: [NKRecommendation]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getRecommendedFiles(account: account,
                                options: options,
                                request: request,
                                taskHandler: taskHandler) { account, recommendations, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    recommendations: recommendations,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
}
