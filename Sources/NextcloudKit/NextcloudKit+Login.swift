// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    // MARK: - App Password

    /// Retrieves an app password (token) for the given user credentials and server URL.
    ///
    /// Parameters:
    /// - url: The base server URL (e.g., https://cloud.example.com).
    /// - user: The username for authentication.
    /// - password: The user's password.
    /// - userAgent: Optional user-agent string to include in the request.
    /// - options: Optional request configuration (headers, queue, etc.).
    /// - taskHandler: Callback for observing the underlying URLSessionTask.
    /// - completion: Returns the token string (if any), raw response data, and NKError result.
    func getAppPassword(url: String,
                        user: String,
                        password: String,
                        userAgent: String? = nil,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ token: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/core/getapppassword"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: url, endpoint: endpoint) else {
            return options.queue.async { completion(nil, nil, .urlError) }
        }
        var headers: HTTPHeaders = [.authorization(username: user, password: password)]
        if let userAgent = userAgent {
            headers.update(.userAgent(userAgent))
        }
        headers.update(name: "OCS-APIRequest", value: "true")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "GET"), headers: headers)
        } catch {
            return options.queue.async { completion(nil, nil, NKError(error: error)) }
        }

        unauthorizedSession.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(nil, response, error) }
            case .success(let data):
                let apppassword = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataAppPassword(data: data)
                options.queue.async { completion(apppassword, response, .success) }
            }
        }
    }

    /// Asynchronously fetches an app password for the provided user credentials.
    ///
    /// - Parameters:
    ///   - url: The base URL of the Nextcloud server.
    ///   - user: The user login name.
    ///   - password: The user’s password.
    ///   - userAgent: Optional custom user agent for the request.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Callback to observe the task, if needed.
    /// - Returns: A tuple containing the token, response data, and error result.
    func getAppPasswordAsync(url: String,
                             user: String,
                             password: String,
                             userAgent: String? = nil,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        token: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getAppPassword(url: url,
                           user: user,
                           password: password,
                           userAgent: userAgent,
                           options: options,
                           taskHandler: taskHandler) { token, responseData, error in
                continuation.resume(returning: (
                    token: token,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Deletes the app password (token) for a specific account using basic authentication.
    ///
    /// Parameters:
    /// - serverUrl: The full server URL (e.g., https://cloud.example.com).
    /// - username: The username associated with the app password.
    /// - password: The password or app password used for authentication.
    /// - userAgent: Optional user-agent string for the request.
    /// - account: The logical account identifier used in the app.
    /// - options: Optional request configuration (headers, queues, etc.).
    /// - taskHandler: Callback to observe the underlying URLSessionTask.
    /// - completion: Returns the raw response and a possible NKError result.
    func deleteAppPassword(serverUrl: String,
                           username: String,
                           password: String,
                           userAgent: String? = nil,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/core/apppassword"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = self.nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(nil, .urlError) }
        }
        var headers: HTTPHeaders = [.authorization(username: username, password: password)]
        if let userAgent = userAgent {
            headers.update(.userAgent(userAgent))
        }
        headers.update(name: "OCS-APIRequest", value: "true")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "DELETE"), headers: headers)
        } catch {
            return options.queue.async { completion(nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(response, error) }
            case .success:
                options.queue.async { completion(response, .success) }
            }
        }
    }

    /// Asynchronously deletes the current app password/token from the server.
    ///
    /// - Parameters:
    ///   - serverUrl: Full URL of the Nextcloud server.
    ///   - username: The user identifier.
    ///   - password: The password or token used for deletion authorization.
    ///   - userAgent: Optional string to customize the User-Agent header.
    ///   - account: Logical account identifier.
    ///   - options: Configuration options for the request.
    ///   - taskHandler: Optional callback for observing the URLSessionTask.
    /// - Returns: A tuple containing the response and a possible error.
    func deleteAppPasswordAsync(serverUrl: String,
                                username: String,
                                password: String,
                                userAgent: String? = nil,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            deleteAppPassword(serverUrl: serverUrl,
                              username: username,
                              password: password,
                              userAgent: userAgent,
                              account: account,
                              options: options,
                              taskHandler: taskHandler) { responseData, error in
                continuation.resume(returning: (
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    // MARK: - Login Flow V2

    ///
    /// Requests the initiation of a login process and retrieves required information.
    ///
    /// - Returns: A tuple consisting of the `endpoint` to poll for the login status with the `token`. Additionally, the `login` to open for the user to log in.
    ///
    func getLoginFlowV2(serverUrl: String, options: NKRequestOptions = NKRequestOptions(), taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async throws -> (endpoint: URL, login: URL, token: String) {
        try await withCheckedThrowingContinuation { continuation in
            getLoginFlowV2(serverUrl: serverUrl, options: options, taskHandler: taskHandler) { token, endpointString, loginString, _, error in
                if error != .success {
                    continuation.resume(throwing: error)
                    return
                }

                guard let endpointString, let endpointURL = URL(string: endpointString) else {
                    continuation.resume(throwing: NKError.urlError)
                    return
                }

                guard let loginString, let loginURL = URL(string: loginString) else {
                    continuation.resume(throwing: NKError.urlError)
                    return
                }

                guard let token else {
                    continuation.resume(throwing: NKError.invalidData)
                    return
                }

                continuation.resume(returning: (endpointURL, loginURL, token))
            }
        }
    }

    /// Starts the Login Flow v2 process by requesting a login token and associated parameters from the server.
    ///
    /// - Parameters:
    ///   - serverUrl: The base URL of the Nextcloud server used to initiate the login flow.
    ///   - options: An optional `NKRequestOptions` object containing configuration such as API version, custom headers, and execution queue.
    ///   - taskHandler: A closure that provides the `URLSessionTask` used for the request. Useful for monitoring or cancellation.
    ///
    /// - Completion:
    ///   - token: The login token used for polling the login status.
    ///   - endpoint: The endpoint URL to be polled to check login completion.
    ///   - login: A user-visible login URL that can be presented to complete authentication.
    ///   - responseData: The raw `AFDataResponse<Data>` received from the server.
    ///   - error: An `NKError` object representing success or failure of the operation.
    func getLoginFlowV2(serverUrl: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ token: String?, _ endpoint: String?, _ login: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/login/v2"
        guard let url = nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(nil, nil, nil, nil, .urlError) }
        }
        var headers: HTTPHeaders?
        if let userAgent = options.customUserAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
        }

        unauthorizedSession.request(url, method: .post, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(nil, nil, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)

                let token = json["poll"]["token"].string
                let endpoint = json["poll"]["endpoint"].string
                let login = json["login"].string

                options.queue.async { completion(token, endpoint, login, response, .success) }
            }
        }
    }

    /// Asynchronously initiates the Login Flow v2 process to obtain authentication parameters.
    /// - Parameters:
    ///   - serverUrl: The base URL of the Nextcloud server.
    ///   - options: Optional request configuration for API version, queue, etc.
    ///   - taskHandler: Optional callback to observe the `URLSessionTask`.
    /// - Returns: A tuple containing the login token, polling endpoint, login URL, response data, and any encountered error.
    func getLoginFlowV2Async(serverUrl: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        token: String?,
        endpoint: String?,
        login: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getLoginFlowV2(serverUrl: serverUrl,
                           options: options,
                           taskHandler: taskHandler) { token, endpoint, login, responseData, error in
                continuation.resume(returning: (
                    token: token,
                    endpoint: endpoint,
                    login: login,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Polls the login flow V2 endpoint to retrieve login credentials (OAuth-style).
    ///
    /// Parameters:
    /// - token: The login flow token to poll for.
    /// - endpoint: The base URL endpoint (e.g., https://cloud.example.com).
    /// - options: Optional request configuration (version, headers, queues, etc.).
    /// - taskHandler: Callback to observe the underlying URLSessionTask.
    /// - completion: Returns the discovered server URL, loginName, appPassword, the raw response data, and any NKError.
    func getLoginFlowV2Poll(token: String,
                            endpoint: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ server: String?, _ loginName: String?, _ appPassword: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let serverUrl = endpoint + "?token=" + token
        guard let url = serverUrl.asUrl else {
            return options.queue.async { completion(nil, nil, nil, nil, .urlError) }
        }
        var headers: HTTPHeaders?
        if let userAgent = options.customUserAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
        }

        unauthorizedSession.request(url, method: .post, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(nil, nil, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let server = json["server"].string
                let loginName = json["loginName"].string
                let appPassword = json["appPassword"].string

                options.queue.async { completion(server, loginName, appPassword, response, .success) }
            }
        }
    }

    /// Asynchronously polls the login flow V2 endpoint for login credentials.
    ///
    /// - Parameters:
    ///   - token: The token used in the login flow process.
    ///   - endpoint: Full base endpoint URL to call the polling API.
    ///   - options: Request configuration such as version, headers, queue.
    ///   - taskHandler: Optional callback to observe the underlying URLSessionTask.
    /// - Returns: A tuple with server URL, login name, app password, raw response, and NKError.
    func getLoginFlowV2PollAsync(token: String,
                                 endpoint: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        server: String?,
        loginName: String?,
        appPassword: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getLoginFlowV2Poll(token: token,
                               endpoint: endpoint,
                               options: options,
                               taskHandler: taskHandler) { server, loginName, appPassword, responseData, error in
                continuation.resume(returning: (
                    server: server,
                    loginName: loginName,
                    appPassword: appPassword,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
}
