// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Retrieves the user status from the Nextcloud server.
    ///
    /// - Parameters:
    ///   - userId: Optional user ID to query (if `nil`, fetches the status for the authenticated user).
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options (headers, queue, version, etc.).
    ///   - taskHandler: Callback for monitoring the `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The user account used.
    ///     - clearAt: Optional expiration `Date` of the status.
    ///     - icon: Optional status icon name.
    ///     - message: Optional status message.
    ///     - messageId: Optional ID of the predefined message.
    ///     - messageIsPredefined: Indicates whether the message is predefined.
    ///     - status: Optional raw status value.
    ///     - statusIsUserDefined: Indicates if the status was set manually by the user.
    ///     - userId: The actual user ID returned by the server.
    ///     - responseData: Raw response data from the server.
    ///     - error: Result as `NKError`.
    func getUserStatus(userId: String? = nil,
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       completion: @escaping (_ account: String, _ clearAt: Date?, _ icon: String?, _ message: String?, _ messageId: String?, _ messageIsPredefined: Bool, _ status: String?, _ statusIsUserDefined: Bool, _ userId: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status"
        if let userId = userId {
            endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/\(userId)"
        }
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, nil, false, nil, false, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously retrieves the user status from the Nextcloud server.
    ///
    /// - Parameters: Same as the sync version.
    /// - Returns: A tuple with explicitly named values describing the user status.
    func getUserStatusAsync(userId: String? = nil,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        clearAt: Date?,
        icon: String?,
        message: String?,
        messageId: String?,
        messageIsPredefined: Bool,
        status: String?,
        statusIsUserDefined: Bool,
        userId: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getUserStatus(userId: userId,
                          account: account,
                          options: options,
                          taskHandler: taskHandler) { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    clearAt: clearAt,
                    icon: icon,
                    message: message,
                    messageId: messageId,
                    messageIsPredefined: messageIsPredefined,
                    status: status,
                    statusIsUserDefined: statusIsUserDefined,
                    userId: userId,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }


    /// Sets the current user status on the Nextcloud server.
    ///
    /// Parameters:
    /// - status: The raw status value to be set (e.g. "online", "away", etc.).
    /// - account: The Nextcloud account performing the operation.
    /// - options: Optional request configuration.
    /// - taskHandler: Callback for the underlying `URLSessionTask`.
    /// - completion: Returns the account, the raw response data, and any resulting NKError.
    func setUserStatus(status: String,
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/status"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let parameters = [
            "statusType": String(status)
        ]

        nkSession.sessionData.request(url, method: .put, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously sets the current user status on the Nextcloud server.
    ///
    /// - Parameters: Same as the sync version.
    /// - Returns: A tuple with the account, responseData, and NKError.
    func setUserStatusAsync(status: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            setUserStatus(status: status,
                          account: account,
                          options: options,
                          taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Sets a predefined custom message for the user's status on the Nextcloud server.
    ///
    /// - Parameters:
    ///   - messageId: The identifier of the predefined message to be set.
    ///   - clearAt: A UNIX timestamp (in seconds) after which the message should expire (use `0` for no expiration).
    ///   - account: The account identifier used to authenticate the request.
    ///   - options: Optional request configuration, including headers, queue, and API version.
    ///   - taskHandler: Callback invoked with the `URLSessionTask` when the request is created.
    ///   - completion: Completion handler called with:
    ///     - account: The account used in the operation.
    ///     - responseData: The raw server response.
    ///     - error: A `NKError` indicating success or failure.
    func setCustomMessagePredefined(messageId: String,
                                    clearAt: Double,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                    completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message/predefined"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var parameters = [
            "messageId": String(messageId)
        ]
        if clearAt > 0 {
            parameters["clearAt"] = String(clearAt)
        }

        nkSession.sessionData.request(url, method: .put, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously sets a predefined custom message with optional expiration.
    ///
    /// Parameters:
    /// - messageId: The identifier of the predefined message to set.
    /// - clearAt: Expiration timestamp (UNIX time) after which the message is cleared (optional, use 0 to skip).
    /// - account: The Nextcloud account performing the operation.
    /// - options: Optional request configuration (headers, queue, etc.).
    /// - taskHandler: Callback for monitoring the underlying URLSessionTask.
    /// - Returns: A tuple containing the account identifier, the raw response, and any resulting NKError.
    func setCustomMessagePredefinedAsync(messageId: String,
                                         clearAt: Double,
                                         account: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            setCustomMessagePredefined(messageId: messageId,
                                       clearAt: clearAt,
                                       account: account,
                                       options: options,
                                       taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Sets a custom user-defined status message on the Nextcloud server.
    ///
    /// Parameters:
    /// - statusIcon: Optional icon name representing the status.
    /// - message: The custom status message string to display to other users.
    /// - clearAt: Expiration timestamp (in UNIX time format) for the status message; use 0 to disable automatic clearing.
    /// - account: The Nextcloud account identifier on which to apply the status.
    /// - options: Optional request configuration such as headers, queue, or task description.
    /// - taskHandler: Closure invoked when the URLSessionTask is created, used for task tracking or debugging.
    /// - completion: Completion handler returning:
    ///     - account: The account identifier used.
    ///     - responseData: The raw Alamofire response data (if any).
    ///     - error: An `NKError` indicating success or failure.
    func setCustomMessageUserDefined(statusIcon: String?,
                                     message: String,
                                     clearAt: Double,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message/custom"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

        nkSession.sessionData.request(url, method: .put, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously sets a custom user-defined status message.
    ///
    /// Parameters:
    /// - statusIcon: Optional icon to display with the message.
    /// - message: The custom status message string.
    /// - clearAt: Timestamp (UNIX time) when the message should expire (use 0 to skip).
    /// - account: The Nextcloud account performing the operation.
    /// - options: Request options such as headers, task description, queue.
    /// - taskHandler: Callback for URLSessionTask monitoring.
    ///
    /// Returns: A tuple containing account, responseData, and any resulting NKError.
    func setCustomMessageUserDefinedAsync(statusIcon: String?,
                                          message: String,
                                          clearAt: Double,
                                          account: String,
                                          options: NKRequestOptions = NKRequestOptions(),
                                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            setCustomMessageUserDefined(statusIcon: statusIcon,
                                        message: message,
                                        clearAt: clearAt,
                                        account: account,
                                        options: options,
                                        taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Clears any custom or predefined user status message currently set on the Nextcloud server.
    ///
    /// Parameters:
    /// - account: The Nextcloud account identifier whose status message should be cleared.
    /// - options: Optional request configuration such as custom headers, dispatch queue, or task description.
    /// - taskHandler: Closure called when the `URLSessionTask` is created, useful for debugging or tracking purposes.
    /// - completion: Completion handler returning:
    ///     - account: The account identifier used.
    ///     - responseData: The raw Alamofire response object, if available.
    ///     - error: An `NKError` representing the result of the operation (success or failure).
    func clearMessage(account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously clears any user status message (custom or predefined) on the Nextcloud server.
    ///
    /// Parameters:
    /// - account: The Nextcloud account identifier whose status message will be cleared.
    /// - options: Optional `NKRequestOptions` to customize the request (e.g., headers, queue).
    /// - taskHandler: Callback triggered upon creation of the `URLSessionTask`.
    ///
    /// Returns: A tuple containing:
    /// - account: The account identifier used for the operation.
    /// - responseData: The raw `AFDataResponse<Data>` object returned by Alamofire.
    /// - error: The resulting `NKError`, either `.success` or a failure case.
    func clearMessageAsync(account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            clearMessage(account: account,
                         options: options,
                         taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Retrieves the list of predefined user statuses + messages (e.g., "Commuting", "In a meeting", "Be right back") from the Nextcloud server.
    ///
    /// - Parameters:
    ///   - account: The Nextcloud account identifier performing the request.
    ///   - options: Optional `NKRequestOptions` to customize the request (e.g., custom headers, queue).
    ///   - taskHandler: Callback triggered when the `URLSessionTask` is created.
    ///   - completion: Completion handler returning:
    ///     - account: The account identifier used for the request.
    ///     - userStatuses: An optional array of predefined `NKUserStatus` objects.
    ///     - responseData: Raw `AFDataResponse<Data>` from Alamofire.
    ///     - error: Resulting `NKError` describing success or failure.
    func getUserStatusPredefinedStatuses(account: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                         completion: @escaping (_ account: String, _ userStatuses: [NKUserStatus]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/predefined_statuses"
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

    /// Asynchronously retrieves the predefined user statuses available on the Nextcloud server.
    ///
    /// These predefined statuses are managed by the server and include standardized status types
    /// (e.g. "online", "away", "do not disturb") which can be selected by users.
    ///
    /// Parameters:
    /// - account: The identifier of the Nextcloud account making the request.
    /// - options: Optional request configuration (headers, queue, API version, etc.).
    /// - taskHandler: A closure that is called when the URLSessionTask is created.
    ///
    /// Returns: A tuple containing:
    /// - account: The account used for the request.
    /// - userStatuses: An optional array of `NKUserStatus` representing the predefined statuses.
    /// - responseData: The raw HTTP response returned from the server.
    /// - error: The result of the request as an `NKError` object.
    func getUserStatusPredefinedStatusesAsync(account: String,
                                              options: NKRequestOptions = NKRequestOptions(),
                                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        userStatuses: [NKUserStatus]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getUserStatusPredefinedStatuses(account: account,
                                            options: options,
                                            taskHandler: taskHandler) { account, userStatuses, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    userStatuses: userStatuses,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Retrieves a list of user statuses from the Nextcloud server.
    ///
    /// - Parameters:
    ///   - limit: The maximum number of statuses to retrieve.
    ///   - offset: The number of statuses to skip before starting to collect the results.
    ///   - account: The account identifier used to perform the request.
    ///   - options: Optional request configuration (headers, queue, etc.).
    ///   - taskHandler: Callback invoked with the `URLSessionTask` when the request is created.
    ///   - completion: Completion handler called with:
    ///     - account: The account used in the operation.
    ///     - userStatuses: An array of `NKUserStatus` objects, or `nil` if an error occurred.
    ///     - responseData: The raw server response.
    ///     - error: A `NKError` indicating success or failure.
    func getUserStatusRetrieveStatuses(limit: Int,
                                       offset: Int,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                       completion: @escaping (_ account: String, _ userStatuses: [NKUserStatus]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/statuses"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters = [
            "limit": String(limit),
            "offset": String(offset)
        ]

        nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously retrieves a list of user statuses from the Nextcloud server.
    ///
    /// - Parameters:
    ///   - limit: The maximum number of statuses to retrieve.
    ///   - offset: The number of statuses to skip before collecting results.
    ///   - account: The account identifier used to perform the request.
    ///   - options: Optional request configuration (headers, queue, etc.).
    ///   - taskHandler: Callback invoked with the `URLSessionTask` when the request is created.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the request.
    ///   - userStatuses: An array of `NKUserStatus` objects, or `nil` if an error occurred.
    ///   - responseData: The raw server response.
    ///   - error: A `NKError` describing the result.
    func getUserStatusRetrieveStatusesAsync(limit: Int,
                                            offset: Int,
                                            account: String,
                                            options: NKRequestOptions = NKRequestOptions(),
                                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        userStatuses: [NKUserStatus]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getUserStatusRetrieveStatuses(limit: limit,
                                          offset: offset,
                                          account: account,
                                          options: options,
                                          taskHandler: taskHandler) { account, userStatuses, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    userStatuses: userStatuses,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
}
