// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func getRecommendedFiles(account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             request: @escaping (DataRequest?) -> Void = { _ in },
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ recommendations: [NKRecommendation]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/recommendations/api/v1/recommendations"
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, checkUnauthorized: true, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let tosRequest = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor()).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
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
}
