// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON
import SwiftyXMLParser

public extension NextcloudKit {
    private var systemTagsPath: String { "/remote.php/dav/systemtags/" }
    private var systemTagRelationsFilesPath: String { "/remote.php/dav/systemtags-relations/files/" }

    /// Returns the list of tags available for the account.
    ///
    /// - Parameters:
    ///   - account: The account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for the underlying URL session task.
    ///   - completion: Completion handler returning account, tags, raw response and error.
    func getTags(account: String,
                 options: NKRequestOptions = NKRequestOptions(),
                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                 completion: @escaping (_ account: String, _ tags: [NKTag]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options, accept: "application/xml") else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let endpoint = nkSession.urlBase + systemTagsPath
        guard let url = endpoint.encodedToUrl else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let method = HTTPMethod(rawValue: "PROPFIND")
        headers.update(name: "Depth", value: "1")
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodySystemTags.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async { completion(account, nil, response, error) }
                case .success:
                    guard let xmlData = response.data else {
                        return options.queue.async { completion(account, nil, response, .invalidData) }
                    }
                    let tags = self.convertSystemTags(xmlData: xmlData)
                    options.queue.async { completion(account, tags, response, .success) }
                }
            }
    }

    /// Async wrapper around ``getTags(account:options:taskHandler:completion:)``.
    func getTagsAsync(account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        tags: [NKTag]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getTags(account: account, options: options, taskHandler: taskHandler) { account, tags, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    tags: tags,
                    responseData: responseData,
                    error: error
                ))
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
    ///   - completion: Completion handler returning account, raw response and error.
    func createTag(name: String,
                   account: String,
                   options: NKRequestOptions = NKRequestOptions(),
                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                   completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json", accept: "application/json"),
              let url = (nkSession.urlBase + systemTagsPath).encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .post, headers: headers)
            urlRequest.timeoutInterval = options.timeout
            let payload = ["name": name]
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                let result = self.evaluateResponse(response)
                options.queue.async { completion(account, response, result) }
            }
    }

    /// Async wrapper around ``createTag(name:account:options:taskHandler:completion:)``.
    func createTagAsync(name: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            createTag(name: name, account: account, options: options, taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
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
    ///   - completion: Completion handler returning account, raw response and error.
    func addTagToFile(tagId: String,
                      fileId: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json", accept: "application/json"),
              let url = (nkSession.urlBase + systemTagRelationsFilesPath + fileId + "/" + tagId).encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .put, headers: headers)
            urlRequest.timeoutInterval = options.timeout
            urlRequest.httpBody = Data()
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                let result = self.evaluateResponse(response)
                options.queue.async { completion(account, response, result) }
            }
    }

    /// Async wrapper around ``addTagToFile(tagId:fileId:account:options:taskHandler:completion:)``.
    func addTagToFileAsync(tagId: String,
                           fileId: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            addTagToFile(tagId: tagId, fileId: fileId, account: account, options: options, taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
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
    ///   - completion: Completion handler returning account, raw response and error.
    func removeTagFromFile(tagId: String,
                           fileId: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json", accept: "application/json"),
              let url = (nkSession.urlBase + systemTagRelationsFilesPath + fileId + "/" + tagId).encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .delete, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                let result = self.evaluateResponse(response)
                options.queue.async { completion(account, response, result) }
            }
    }

    /// Async wrapper around ``removeTagFromFile(tagId:fileId:account:options:taskHandler:completion:)``.
    func removeTagFromFileAsync(tagId: String,
                                fileId: String,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            removeTagFromFile(tagId: tagId, fileId: fileId, account: account, options: options, taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    private func convertSystemTags(xmlData: Data) -> [NKTag] {
        let xml = XML.parse(xmlData)
        let responses = xml["d:multistatus", "d:response"]
        var tags: [NKTag] = []

        for response in responses {
            let propstat = response["d:propstat"][0]
            guard let id = propstat["d:prop", "oc:id"].text,
                  let name = propstat["d:prop", "oc:display-name"].text else {
                continue
            }

            var color: String?
            if let colorHex = propstat["d:prop", "nc:color"].text, !colorHex.isEmpty {
                color = colorHex.hasPrefix("#") ? colorHex : "#\(colorHex)"
            }

            tags.append(NKTag(id: id, name: name, color: color))
        }

        return tags
    }
}
