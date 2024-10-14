//
// SPDX-FileCopyrightText: 2023 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation
import Alamofire

public extension NextcloudKit {
    func setLivephoto(serverUrlfileNamePath: String,
                      livePhotoFile: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        guard let url = serverUrlfileNamePath.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/xml")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyLivephoto, livePhotoFile)
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }
}
