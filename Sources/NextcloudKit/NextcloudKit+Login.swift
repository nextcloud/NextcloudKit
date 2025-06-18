// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    // MARK: - App Password
    func getAppPassword(url: String,
                        user: String,
                        password: String,
                        userAgent: String? = nil,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ token: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/core/getapppassword"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: url, endpoint: endpoint, options: options) else {
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
                let apppassword = NKDataFileXML().convertDataAppPassword(data: data)
                options.queue.async { completion(apppassword, response, .success) }
            }
        }
    }

    func deleteAppPassword(serverUrl: String,
                           username: String,
                           password: String,
                           userAgent: String? = nil,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/core/apppassword"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = self.nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint, options: options) else {
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

    func getLoginFlowV2(serverUrl: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ token: String?, _ endpoint: String?, _ login: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/login/v2"
        guard let url = nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint, options: options) else {
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
}
