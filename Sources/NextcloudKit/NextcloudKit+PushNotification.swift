//
//  NextcloudKit+PushNotification.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 22/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
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

public extension NextcloudKit {
    func subscribingPushNotification(serverUrl: String,
                                     pushTokenHash: String,
                                     devicePublicKey: String,
                                     proxyServerUrl: String,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                     completion: @escaping (_ account: String, _ deviceIdentifier: String?, _ signature: String?, _ publicKey: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/push"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, nil, .urlError) }
        }
        let parameters = [
            "pushTokenHash": pushTokenHash,
            "devicePublicKey": devicePublicKey,
            "proxyServer": proxyServerUrl
        ]

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let deviceIdentifier = json["ocs"]["data"]["deviceIdentifier"].stringValue
                    let signature = json["ocs"]["data"]["signature"].stringValue
                    let publicKey = json["ocs"]["data"]["publicKey"].stringValue
                    options.queue.async { completion(account, deviceIdentifier, signature, publicKey, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, nil, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func unsubscribingPushNotification(serverUrl: String,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                       completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data?>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/push"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    func subscribingPushProxy(proxyServerUrl: String,
                              pushToken: String,
                              deviceIdentifier: String,
                              signature: String,
                              publicKey: String,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                              completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data?>?, _ error: NKError) -> Void) {
        let endpoint = "devices?format=json"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = self.nkCommonInstance.createStandardUrl(serverUrl: proxyServerUrl, endpoint: endpoint, options: options),
              let userAgent = options.customUserAgent else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let parameters = [
            "pushToken": pushToken,
            "deviceIdentifier": deviceIdentifier,
            "deviceIdentifierSignature": signature,
            "userPublicKey": publicKey
        ]
        let headers = HTTPHeaders(arrayLiteral: .userAgent(userAgent))

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    func unsubscribingPushProxy(proxyServerUrl: String,
                                deviceIdentifier: String,
                                signature: String,
                                publicKey: String,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data?>?, _ error: NKError) -> Void) {
        let endpoint = "devices"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = self.nkCommonInstance.createStandardUrl(serverUrl: proxyServerUrl, endpoint: endpoint, options: options),
              let userAgent = options.customUserAgent else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let parameters = [
            "deviceIdentifier": deviceIdentifier,
            "deviceIdentifierSignature": signature,
            "userPublicKey": publicKey
        ]
        let headers = HTTPHeaders(arrayLiteral: .userAgent(userAgent))

        nkSession.sessionData.request(url, method: .delete, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
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
