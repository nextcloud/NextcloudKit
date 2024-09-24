//
//  NextcloudKit+Comments.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 21/05/2020.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import Alamofire

public extension NextcloudKit {
    func getComments(fileId: String,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ items: [NKComments]?, _ data: Data?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil,nil, .urlError) }
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

        nkSession.sessionData.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
        ///
        options.contentType = "application/json"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: .post, headers: headers)
            let parameters = "{\"actorType\":\"users\",\"verb\":\"comment\",\"message\":\"" + message + "\"}"
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)/\(messageId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyCommentsUpdate, message)
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)/\(messageId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, .urlError) }
        }
        let serverUrlEndpoint = nkSession.urlBase + "/" + nkSession.dav + "/comments/files/\(fileId)"
        guard let url = serverUrlEndpoint.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyCommentsMarkAsRead)
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
