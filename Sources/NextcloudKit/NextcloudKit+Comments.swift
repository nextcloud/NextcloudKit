// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

public extension NextcloudKit {
    func getComments(fileId: String,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ items: [NKComments]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPFIND")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyComments.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, nil, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success:
                if let xmlData = response.data {
                    let items = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataComments(xmlData: xmlData)
                    options.queue.async { completion(account, items, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, .invalidData) }
                }
            }
        }
    }

    /// Asynchronously retrieves comments for a given file ID.
    /// - Parameters:
    ///   - fileId: The file identifier to fetch comments for.
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, list of comments (if any), response data, and error.
    func getCommentsAsync(fileId: String,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, [NKComments]?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            getComments(fileId: fileId,
                        account: account,
                        options: options,
                        taskHandler: taskHandler) { account, items, responseData, error in
                continuation.resume(returning: (account, items, responseData, error))
            }
        }
    }

    func putComments(fileId: String,
                     message: String,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/json"
        ///
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: .post, headers: headers)
            let parameters = "{\"actorType\":\"users\",\"verb\":\"comment\",\"message\":\"" + message + "\"}"
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously adds a comment to a file.
    /// - Parameters:
    ///   - fileId: The file identifier to comment on.
    ///   - message: The comment message.
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, response data, and error.
    func putCommentsAsync(fileId: String,
                          message: String,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            putComments(fileId: fileId,
                        message: message,
                        account: account,
                        options: options,
                        taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (account, responseData, error))
            }
        }
    }

    func updateComments(fileId: String,
                        messageId: String,
                        message: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)/\(messageId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyCommentsUpdate, message)
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously updates an existing comment on a file.
    /// - Parameters:
    ///   - fileId: The file identifier.
    ///   - messageId: The ID of the comment to update.
    ///   - message: The updated comment message.
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, response data, and error.
    func updateCommentsAsync(fileId: String,
                             messageId: String,
                             message: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            updateComments(fileId: fileId,
                           messageId: messageId,
                           message: message,
                           account: account,
                           options: options,
                           taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (account, responseData, error))
            }
        }
    }

    // Deletes a specific comment from a file on the server for a given Nextcloud account.
    // It performs an HTTP request (typically DELETE) and returns the result through a completion handler.
    //
    // Parameters:
    // - fileId: The identifier of the file the comment belongs to.
    // - messageId: The identifier of the comment to be deleted.
    // - account: The Nextcloud account performing the operation.
    // - options: Optional request options such as custom headers or retry policy (default is empty).
    // - taskHandler: A closure to access the underlying URLSessionTask, useful for progress or cancellation.
    // - completion: Completion handler returning the account, the raw response (if any), and an NKError.
    func deleteComments(fileId: String,
                        messageId: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)/\(messageId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously deletes a specific comment from a file for the given account.
    /// - Parameters:
    ///   - fileId: The identifier of the file containing the comment.
    ///   - messageId: The ID of the comment to delete.
    ///   - account: The account performing the request.
    ///   - options: Optional request options (default is empty).
    ///   - taskHandler: Closure to access the URLSessionTask (default is empty).
    /// - Returns: A tuple containing the account identifier, optional response, and NKError.
    func deleteCommentsAsync(fileId: String,
                             messageId: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            deleteComments(fileId: fileId,
                           messageId: messageId,
                           account: account,
                           options: options,
                           taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (account, responseData, error))
            }
        }
    }

    // Marks all comments on a given file as read for the specified Nextcloud account.
    // It performs an HTTP request (likely POST or PUT) to update the read status on the server.
    //
    // Parameters:
    // - fileId: The identifier of the file whose comments should be marked as read.
    // - account: The Nextcloud account performing the operation.
    // - options: Optional request options (default is empty).
    // - taskHandler: A closure to access the underlying URLSessionTask (default is no-op).
    // - completion: Completion handler returning the account, the raw response, and any NKError.
    func markAsReadComments(fileId: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyCommentsMarkAsRead)
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously marks all comments on a file as read for the given account.
    /// - Parameters:
    ///   - fileId: The identifier of the file.
    ///   - account: The account performing the request.
    ///   - options: Optional request options (default is empty).
    ///   - taskHandler: Optional closure to access the URLSessionTask (default is no-op).
    /// - Returns: A tuple with the account, optional response, and NKError.
    func markAsReadCommentsAsync(fileId: String,
                                 account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            markAsReadComments(fileId: fileId,
                               account: account,
                               options: options,
                               taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (account, responseData, error))
            }
        }
    }
}
