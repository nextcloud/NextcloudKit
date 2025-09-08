// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Henrik Sorch
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Retrieves the hovercard information for a specific user from the Nextcloud server.
    /// - Parameters:
    ///   - userId: The identifier of the user whose hovercard is being requested.
    ///   - account: The Nextcloud account used to perform the request.
    ///   - options: Optional request options for customizing the API call.
    ///   - taskHandler: Closure for observing the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning the account, the `NKHovercard` result, raw response data, and any error encountered.
    func getHovercard(for userId: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ result: NKHovercard?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/hovercard/v1/\(userId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]
                guard json["ocs"]["meta"]["statuscode"].int == 200,
                      let result = NKHovercard(jsonData: data)
                else {
                    let error = NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)
                    options.queue.async { completion(account, nil, response, error) }
                    return
                }
                options.queue.async { completion(account, result, response, .success) }
            }
        }
    }

    /// Asynchronously retrieves the hovercard information for a specific user from the Nextcloud server.
    /// - Parameters:
    ///   - userId: The identifier of the user whose hovercard is being requested.
    ///   - account: The Nextcloud account used to perform the request.
    ///   - options: Optional request options for customizing the API call.
    ///   - taskHandler: Closure for observing the underlying `URLSessionTask`.
    /// - Returns: A tuple containing the account, the `NKHovercard` result, raw response data, and any error encountered.
    func getHovercardAsync(for userId: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        result: NKHovercard?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getHovercard(for: userId,
                         account: account,
                         options: options,
                         taskHandler: taskHandler) { account, result, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    result: result,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
}

public class NKHovercard: NSObject {
    public let userId, displayName: String
    public let actions: [Action]

    init?(jsonData: JSON) {
        guard let userId = jsonData["userId"].string,
              let displayName = jsonData["displayName"].string,
              let actions = jsonData["actions"].array?.compactMap(Action.init)
        else {
            return nil
        }
        self.userId = userId
        self.displayName = displayName
        self.actions = actions
    }

    public class Action: NSObject {
        public let title: String
        public let icon: String
        public let hyperlink: String
        public var hyperlinkUrl: URL? { URL(string: hyperlink) }
        public let appId: String

        init?(jsonData: JSON) {
            guard let title = jsonData["title"].string,
                  let icon = jsonData["icon"].string,
                  let hyperlink = jsonData["hyperlink"].string,
                  let appId = jsonData["appId"].string
            else {
                return nil
            }
            self.title = title
            self.icon = icon
            self.hyperlink = hyperlink
            self.appId = appId
        }
    }
}
