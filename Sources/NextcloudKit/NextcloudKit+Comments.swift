// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

public extension NextcloudKit {
    /// Retrieves all comments associated with a specific file from the server.
    /// This is typically used in collaboration features to display user discussions or annotations.
    ///
    /// - Parameters:
    ///   - fileId: Identifier of the file whose comments are being retrieved.
    ///   - account: The Nextcloud account requesting the comments.
    ///   - options: Optional request customization (headers, timeout, etc.).
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    ///   - completion: Completion handler returning the account, comment list, raw response, and NKError.
    func getComments(fileId: String,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ items: [NKComments]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, accept: "application/xml") else {
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

    /// Asynchronously retrieves the list of comments for a given file ID.
    /// - Parameters:
    ///   - fileId: File identifier to fetch comments for.
    ///   - account: The account executing the request.
    ///   - options: Optional configuration for the HTTP request.
    ///   - taskHandler: Callback for accessing the URLSessionTask.
    /// - Returns: A tuple with named values for account, comment list, response, and error.
    func getCommentsAsync(fileId: String,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        items: [NKComments]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getComments(fileId: fileId,
                        account: account,
                        options: options,
                        taskHandler: taskHandler) { account, items, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    items: items,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Adds a new comment to a specific file.
    /// Useful for enabling collaboration or user discussions directly on file items.
    ///
    /// - Parameters:
    ///   - fileId: Identifier of the file to which the comment will be added.
    ///   - message: The content of the comment to post.
    ///   - account: The Nextcloud account posting the comment.
    ///   - options: Optional HTTP configuration (headers, timeout, etc.).
    ///   - taskHandler: Optional callback to access the URLSessionTask.
    ///   - completion: Completion handler with account, response, and error.
    func putComments(fileId: String,
                     message: String,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json") else {
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

    /// Asynchronously posts a new comment to a file.
    /// - Parameters:
    ///   - fileId: The file to comment on.
    ///   - message: The comment body.
    ///   - account: The account sending the request.
    ///   - options: Optional network options.
    ///   - taskHandler: Callback to monitor the network task.
    /// - Returns: A tuple with account, response data, and any resulting error.
    func putCommentsAsync(fileId: String,
                          message: String,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            putComments(fileId: fileId,
                        message: message,
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

    /// Updates the content of an existing comment on a file.
    /// Useful for editing or correcting previously posted comments.
    ///
    /// - Parameters:
    ///   - fileId: Identifier of the file that contains the comment.
    ///   - messageId: Identifier of the specific comment to be updated.
    ///   - message: The new content to replace the old comment.
    ///   - account: The Nextcloud account performing the update.
    ///   - options: Optional HTTP configuration (e.g., headers, timeout).
    ///   - taskHandler: Optional callback to inspect the created URLSessionTask.
    ///   - completion: Completion handler returning account, response, and NKError.
    func updateComments(fileId: String,
                        messageId: String,
                        message: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml") else {
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

    /// Asynchronously updates a specific comment on a file.
    /// - Parameters:
    ///   - fileId: File containing the comment.
    ///   - messageId: ID of the comment to be updated.
    ///   - message: New content of the comment.
    ///   - account: User account executing the update.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Callback for accessing the request task.
    /// - Returns: A tuple with account, response data, and error.
    func updateCommentsAsync(fileId: String,
                             messageId: String,
                             message: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            updateComments(fileId: fileId,
                           messageId: messageId,
                           message: message,
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

    /// Deletes a specific comment from a file on the server for a given Nextcloud account.
    /// It performs an HTTP request (typically DELETE) and returns the result through a completion handler.
    ///
    /// - Parameters:
    ///   - fileId: The identifier of the file the comment belongs to.
    ///   - messageId: The identifier of the comment to be deleted.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Optional request options such as custom headers or retry policy (default is empty).
    ///   - taskHandler: A closure to access the underlying URLSessionTask, useful for progress or cancellation.
    ///   - completion: Completion handler returning the account, the raw response (if any), and an NKError.
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

    /// Asynchronously deletes a comment from a file.
    /// - Parameters:
    ///   - fileId: File containing the comment.
    ///   - messageId: ID of the comment to be deleted.
    ///   - account: User account performing the deletion.
    ///   - options: Additional configuration for the HTTP request.
    ///   - taskHandler: Optional handler for the URLSessionTask.
    /// - Returns: A tuple with account, server response, and an NKError.
    func deleteCommentsAsync(fileId: String,
                             messageId: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            deleteComments(fileId: fileId,
                           messageId: messageId,
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

    /// Marks all comments on a given file as read for the specified Nextcloud account.
    /// It performs an HTTP request (likely POST or PUT) to update the read status on the server.
    ///
    /// - Parameters:
    ///   - fileId: The identifier of the file whose comments should be marked as read.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Optional request options (default is empty).
    ///   - taskHandler: A closure to access the underlying URLSessionTask (default is no-op).
    ///   - completion: Completion handler returning the account, the raw response, and any NKError.
    func markAsReadComments(fileId: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml") else {
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

    /// Asynchronously marks all comments on a file as read.
    /// - Parameters:
    ///   - fileId: File whose comments should be marked as read.
    ///   - account: The account executing the read marking.
    ///   - options: Optional configuration for the request.
    ///   - taskHandler: Optional handler for the URLSessionTask.
    /// - Returns: A tuple containing the account, response data, and any NKError.
    func markAsReadCommentsAsync(fileId: String,
                                 account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            markAsReadComments(fileId: fileId,
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
}
