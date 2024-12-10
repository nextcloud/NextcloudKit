// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func getTermsOfService(account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           request: @escaping (DataRequest?) -> Void = { _ in },
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ tos: NKTermsOfService?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/terms_of_service/terms"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let tosRequest = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .success(let jsonData):
                let tos = NKTermsOfService()
                if tos.loadFromJSON(jsonData), let meta = tos.getMeta() {
                    if meta.statuscode == 200 {
                        options.queue.async { completion(account, tos, response, .success) }
                    } else {
                        options.queue.async { completion(account, tos, response, NKError(errorCode: meta.statuscode, errorDescription: meta.message, responseData: jsonData)) }
                    }
                } else {
                    options.queue.async { completion(account, nil, response, .invalidData) }
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            }
        }
        options.queue.async { request(tosRequest) }
    }

    func signTermsOfService(termId: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/terms_of_service/sign"
        let parameters: [String: Any] = ["termId": termId]
        ///
        options.contentType = "application/json"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, response, error) }
            case .success:
                options.queue.async { completion(account, response, .success) }
            }
        }
    }
}
