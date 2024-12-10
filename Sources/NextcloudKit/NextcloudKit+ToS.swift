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
                           completion: @escaping (_ account: String, _ tos: [NKTermsOfService.Term]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
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
                if tos.loadFromJSON(jsonData) {
                    options.queue.async { completion(account, tos.getTerms(), response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: JSON(jsonData), fallbackStatusCode: response.response?.statusCode)) }
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            }
        }
        options.queue.async { request(tosRequest) }
    }
}
