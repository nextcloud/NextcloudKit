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
        guard let nkSession = nkCommonInstance.getSession(account: account),
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

        nkSession.sessionData.request(urlRequest, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    func putComments(fileId: String,
                     message: String,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data?>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/json"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
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

        nkSession.sessionData.request(urlRequest, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    func updateComments(fileId: String,
                        messageId: String,
                        message: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data?>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
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

        nkSession.sessionData.request(urlRequest, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    func deleteComments(fileId: String,
                        messageId: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data?>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)/\(messageId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    func markAsReadComments(fileId: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data?>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
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

        nkSession.sessionData.request(urlRequest, interceptor: nkInterceptor).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
