// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

public extension NextcloudKit {
    private var systemTagsPath: String { "/remote.php/dav/systemtags/" }
    private var systemTagRelationsFilesPath: String { "/remote.php/dav/systemtags-relations/files/" }

    /// Returns the list of tags available for the account.
    ///
    /// - Parameters:
    ///   - account: The account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for the underlying URL session task.
    func getTags(account: String,
                 options: NKRequestOptions = NKRequestOptions(),
                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        tags: [NKTag]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options, accept: "application/xml") else {
            return (
                account: account,
                tags: nil,
                responseData: nil,
                error: .urlError
            )
        }

        let endpoint = nkSession.urlBase + systemTagsPath
        guard let url = endpoint.encodedToUrl else {
            return (
                account: account,
                tags: nil,
                responseData: nil,
                error: .urlError
            )
        }

        let method = HTTPMethod(rawValue: "PROPFIND")
        headers.update(name: "Depth", value: "1")
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodySystemTags.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return (
                account: account,
                tags: nil,
                responseData: nil,
                error: NKError(error: error)
            )
        }

        return await withCheckedContinuation { continuation in
            nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
                .validate(statusCode: 200..<300)
                .onURLSessionTaskCreation { task in
                    task.taskDescription = options.taskDescription
                    taskHandler(task)
                }
                .responseData(queue: self.nkCommonInstance.responseQueue) { response in
                    switch response.result {
                    case .failure(let error):
                        let error = NKError(error: error, afResponse: response, responseData: response.data)
                        continuation.resume(returning: (
                            account: account,
                            tags: nil,
                            responseData: response,
                            error: error
                        ))
                    case .success:
                        guard let xmlData = response.data else {
                            return continuation.resume(returning: (
                                account: account,
                                tags: nil,
                                responseData: response,
                                error: .invalidData
                            ))
                        }
                        let tags = NKTag.parse(xmlData: xmlData)
                        continuation.resume(returning: (
                            account: account,
                            tags: tags,
                            responseData: response,
                            error: .success
                        ))
                    }
                }
        }
    }

    /// Creates a new tag.
    ///
    /// - Parameters:
    ///   - name: Tag display name.
    ///   - account: Account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for the underlying URL session task.
    func createTag(name: String,
                   account: String,
                   options: NKRequestOptions = NKRequestOptions(),
                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json", accept: "application/json"),
              let url = (nkSession.urlBase + systemTagsPath).encodedToUrl else {
            return (
                account: account,
                responseData: nil,
                error: .urlError
            )
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .post, headers: headers)
            urlRequest.timeoutInterval = options.timeout
            let payload = ["name": name]
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return (
                account: account,
                responseData: nil,
                error: NKError(error: error)
            )
        }

        return await withCheckedContinuation { continuation in
            nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
                .validate(statusCode: 200..<300)
                .onURLSessionTaskCreation { task in
                    task.taskDescription = options.taskDescription
                    taskHandler(task)
                }
                .responseData(queue: self.nkCommonInstance.responseQueue) { response in
                    let result = self.evaluateResponse(response)
                    continuation.resume(returning: (
                        account: account,
                        responseData: response,
                        error: result
                    ))
                }
        }
    }

    /// Assigns a tag to a file by file id.
    ///
    /// - Parameters:
    ///   - tagId: The system tag id.
    ///   - fileId: The numeric file id.
    ///   - account: Account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for the underlying URL session task.
    func addTagToFile(tagId: String,
                      fileId: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json", accept: "application/json"),
              let url = (nkSession.urlBase + systemTagRelationsFilesPath + fileId + "/" + tagId).encodedToUrl else {
            return (
                account: account,
                responseData: nil,
                error: .urlError
            )
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .put, headers: headers)
            urlRequest.timeoutInterval = options.timeout
            urlRequest.httpBody = Data()
        } catch {
            return (
                account: account,
                responseData: nil,
                error: NKError(error: error)
            )
        }

        return await withCheckedContinuation { continuation in
            nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
                .validate(statusCode: 200..<300)
                .onURLSessionTaskCreation { task in
                    task.taskDescription = options.taskDescription
                    taskHandler(task)
                }
                .responseData(queue: self.nkCommonInstance.responseQueue) { response in
                    let result = self.evaluateResponse(response)
                    continuation.resume(returning: (
                        account: account,
                        responseData: response,
                        error: result
                    ))
                }
        }
    }

    /// Removes a tag assignment from a file.
    ///
    /// - Parameters:
    ///   - tagId: The system tag id.
    ///   - fileId: The numeric file id.
    ///   - account: Account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for the underlying URL session task.
    func removeTagFromFile(tagId: String,
                           fileId: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json", accept: "application/json"),
              let url = (nkSession.urlBase + systemTagRelationsFilesPath + fileId + "/" + tagId).encodedToUrl else {
            return (
                account: account,
                responseData: nil,
                error: .urlError
            )
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .delete, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return (
                account: account,
                responseData: nil,
                error: NKError(error: error)
            )
        }

        return await withCheckedContinuation { continuation in
            nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
                .validate(statusCode: 200..<300)
                .onURLSessionTaskCreation { task in
                    task.taskDescription = options.taskDescription
                    taskHandler(task)
                }
                .responseData(queue: self.nkCommonInstance.responseQueue) { response in
                    let result = self.evaluateResponse(response)
                    continuation.resume(returning: (
                        account: account,
                        responseData: response,
                        error: result
                    ))
                }
        }
    }

    /// Updates the color of an existing system tag.
    ///
    /// - Parameters:
    ///   - tagId: The system tag id.
    ///   - color: Optional hex color (for example `#FF0000`). Pass `nil` to reset to default.
    ///   - account: Account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for the underlying URL session task.
    func updateTagColor(tagId: String,
                        color: String?,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml"),
              let url = (nkSession.urlBase + systemTagsPath + tagId).encodedToUrl else {
            return (
                account: account,
                responseData: nil,
                error: .urlError
            )
        }

        let method = HTTPMethod(rawValue: "PROPPATCH")
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let requestColor = davTagColorValue(color)
            let body = NSString(
                format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodySystemTagSetColor as NSString,
                requestColor
            ) as String
            urlRequest.httpBody = body.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return (
                account: account,
                responseData: nil,
                error: NKError(error: error)
            )
        }

        return await withCheckedContinuation { continuation in
            nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
                .validate(statusCode: 200..<300)
                .onURLSessionTaskCreation { task in
                    task.taskDescription = options.taskDescription
                    taskHandler(task)
                }
                .responseData(queue: self.nkCommonInstance.responseQueue) { response in
                    let result = self.evaluateResponse(response)
                    continuation.resume(returning: (
                        account: account,
                        responseData: response,
                        error: result
                    ))
                }
        }
    }

    private func davTagColorValue(_ color: String?) -> String {
        guard var value = color?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return ""
        }

        if value.hasPrefix("#") {
            value.removeFirst()
        }

        // DAV system tags accept RGB hex only.
        if value.count == 8 {
            value = String(value.prefix(6))
        }

        return value
    }


    /// Updates the favorite tag through the Files web API, which can be used while a file is locked.
    ///
    /// This endpoint replaces the Files app's personal tag selection with the supplied favorite tag
    /// or an empty selection. It does not modify system tags.
    /// - Parameters:
    ///   - filePath: The unescaped path relative to the account's Files root.
    ///   - favorite: Whether to add or remove the favorite tag.
    ///   - account: The account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for the underlying URL session task.
    func setFavoriteTag(filePath: String,
                        favorite: Bool,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let components = filePath.split(separator: "/")
        guard !components.isEmpty,
              !components.contains(where: { $0 == "." || $0 == ".." }),
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json"),
              let baseURL = try? nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: "index.php/apps/files/api/v1/files"
              )?.asURL() else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        let url = components.reduce(baseURL) { url, component in
            url.appendingPathComponent(String(component))
        }
        let tags = favorite ? ["_$!<Favorite>!$_"] : []
        let request: URLRequest
        do {
            var urlRequest = try URLRequest(url: url, method: .post, headers: headers)
            urlRequest.timeoutInterval = options.timeout
            urlRequest.httpBody = try JSONEncoder().encode(["tags": tags])
            request = urlRequest
        } catch {
            let result = NKError(error: error)
            return options.queue.async { completion(account, nil, result) }
        }

        nkSession.sessionData.request(request, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .responseData(queue: nkCommonInstance.responseQueue) { response in
                let error = self.evaluateResponse(response)
                let confirmedTags = response.value.flatMap {
                    (try? JSONSerialization.jsonObject(with: $0) as? [String: Any])?["tags"] as? [String]
                }
                let result: NKError = error == .success && confirmedTags != tags ? .invalidData : error
                options.queue.async { completion(account, response, result) }
            }
    }

    /// Asynchronously updates the favorite tag through the Files web API.
    func setFavoriteTagAsync(filePath: String,
                             favorite: Bool,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await withCheckedContinuation { continuation in
            setFavoriteTag(filePath: filePath,
                           favorite: favorite,
                           account: account,
                           options: options,
                           taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        }
    }
}
