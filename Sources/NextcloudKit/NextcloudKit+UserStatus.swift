// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func getUserStatus(userId: String? = nil,
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       completion: @escaping (_ account: String, _ clearAt: Date?, _ icon: String?, _ message: String?, _ messageId: String?, _ messageIsPredefined: Bool, _ status: String?, _ statusIsUserDefined: Bool, _ userId: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status"
        if let userId = userId {
            endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/\(userId)"
        }
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, nil, false, nil, false, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, nil, nil, false, nil, false, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {

                    var clearAt: Date?
                    if let clearAtDouble = json["ocs"]["data"]["clearAt"].double {
                        clearAt = Date(timeIntervalSince1970: clearAtDouble)
                    }
                    let icon = json["ocs"]["data"]["icon"].string
                    let message = json["ocs"]["data"]["message"].string
                    let messageId = json["ocs"]["data"]["messageId"].string
                    let messageIsPredefined = json["ocs"]["data"]["messageIsPredefined"].boolValue
                    let status = json["ocs"]["data"]["status"].string
                    let statusIsUserDefined = json["ocs"]["data"]["statusIsUserDefined"].boolValue
                    let userId = json["ocs"]["data"]["userId"].string

                    options.queue.async { completion(account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, nil, nil, nil, false, nil, false, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func setUserStatus(status: String,
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/status"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let parameters = [
            "statusType": String(status)
        ]

        nkSession.sessionData.request(url, method: .put, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    options.queue.async { completion(account, response, .success) }
                } else {
                    options.queue.async { completion(account, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func setCustomMessagePredefined(messageId: String,
                                    clearAt: Double,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                    completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message/predefined"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var parameters = [
            "messageId": String(messageId)
        ]
        if clearAt > 0 {
            parameters["clearAt"] = String(clearAt)
        }

        nkSession.sessionData.request(url, method: .put, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)

                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    options.queue.async { completion(account, response, .success) }
                } else {
                    options.queue.async { completion(account, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func setCustomMessageUserDefined(statusIcon: String?,
                                     message: String,
                                     clearAt: Double,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message/custom"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var parameters = [
            "message": String(message)
        ]
        if statusIcon != nil {
            parameters["statusIcon"] = statusIcon
        }
        if clearAt > 0 {
            parameters["clearAt"] = String(clearAt)
        }

        nkSession.sessionData.request(url, method: .put, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError

                if statusCode == 200 {
                    options.queue.async { completion(account, response, .success) }
                } else {
                    options.queue.async { completion(account, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func clearMessage(account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError

                if statusCode == 200 {
                    options.queue.async { completion(account, response, .success) }
                } else {
                    options.queue.async { completion(account, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func getUserStatusPredefinedStatuses(account: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                         completion: @escaping (_ account: String, _ userStatuses: [NKUserStatus]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/predefined_statuses"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                var userStatuses: [NKUserStatus] = []
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    let ocsdata = json["ocs"]["data"]
                    for (_, subJson): (String, JSON) in ocsdata {
                        let userStatus = NKUserStatus()

                        if let value = subJson["clearAt"]["time"].int {
                            userStatus.clearAtTime = String(value)
                        } else if let value = subJson["clearAt"]["time"].string {
                            userStatus.clearAtTime = value
                        }
                        userStatus.clearAtType = subJson["clearAt"]["type"].string
                        userStatus.icon = subJson["icon"].string
                        userStatus.id = subJson["id"].string
                        userStatus.message = subJson["message"].string
                        userStatus.predefined = true
                        userStatuses.append(userStatus)
                    }
                    options.queue.async { completion(account, userStatuses, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func getUserStatusRetrieveStatuses(limit: Int,
                                       offset: Int,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                       completion: @escaping (_ account: String, _ userStatuses: [NKUserStatus]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/statuses"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters = [
            "limit": String(limit),
            "offset": String(offset)
        ]

        nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                var userStatuses: [NKUserStatus] = []
                if statusCode == 200 {
                    let ocsdata = json["ocs"]["data"]
                    for (_, subJson): (String, JSON) in ocsdata {
                        let userStatus = NKUserStatus()
                        if let value = subJson["clearAt"].double {
                            if value > 0 {
                                userStatus.clearAt = Date(timeIntervalSince1970: value)
                            }
                        }
                        userStatus.icon = subJson["icon"].string
                        userStatus.message = subJson["message"].string
                        userStatus.predefined = false
                        userStatus.userId = subJson["userId"].string
                        userStatuses.append(userStatus)
                    }
                    options.queue.async { completion(account, userStatuses, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
}
