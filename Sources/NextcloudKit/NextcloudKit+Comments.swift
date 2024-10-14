//
// SPDX-FileCopyrightText: 2020 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation
import Alamofire

public extension NextcloudKit {
    func getComments(fileId: String,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ items: [NKComments]?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let dav = self.nkCommonInstance.dav
        let serverUrlEndpoint = urlBase + "/" + dav + "/comments/files/\(fileId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPFIND")
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/xml")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyComments.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, nil, nil, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success:
                if let xmlData = response.data {
                    let items = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataComments(xmlData: xmlData)
                    options.queue.async { completion(account, items, xmlData, .success) }
                } else {
                    options.queue.async { completion(account, nil, nil, .invalidData) }
                }
            }
        }
    }

    func putComments(fileId: String,
                     message: String,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let dav = self.nkCommonInstance.dav
        let serverUrlEndpoint = urlBase + "/" + dav + "/comments/files/\(fileId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/json")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: .post, headers: headers)
            let parameters = "{\"actorType\":\"users\",\"verb\":\"comment\",\"message\":\"" + message + "\"}"
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }

    func updateComments(fileId: String,
                        messageId: String,
                        message: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let dav = self.nkCommonInstance.dav
        let serverUrlEndpoint = urlBase + "/" + dav + "/comments/files/\(fileId)/\(messageId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/xml")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyCommentsUpdate, message)
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }

    func deleteComments(fileId: String,
                        messageId: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let dav = self.nkCommonInstance.dav
        let serverUrlEndpoint = urlBase + "/" + dav + "/comments/files/\(fileId)/\(messageId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }

    func markAsReadComments(fileId: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let dav = self.nkCommonInstance.dav
        let serverUrlEndpoint = urlBase + "/" + dav + "/comments/files/\(fileId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/xml")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyCommentsMarkAsRead)
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }
}
