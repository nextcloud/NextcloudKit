//
//  NextcloudKit+LoginFlowV2.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 07/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import SwiftyJSON

public extension NextcloudKit {
    // MARK: - App Password
    func getAppPassword(url: String,
                        user: String,
                        password: String,
                        userAgent: String? = nil,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ token: String?, _ data: Data?, _ error: NKError) -> Void) {
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
                options.queue.async { completion(nil, nil, error) }
            case .success(let xmlData):
                if let data = xmlData {
                    let apppassword = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataAppPassword(data: data)
                    options.queue.async { completion(apppassword, xmlData, .success) }
                } else {
                    options.queue.async { completion(nil, nil, .xmlError) }
                }
            }
        }
    }

    func deleteAppPassword(serverUrl: String,
                           username: String,
                           password: String,
                           userAgent: String? = nil,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ data: Data?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/core/apppassword"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
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
                options.queue.async { completion(nil, error) }
            case .success(let xmlData):
                options.queue.async { completion(xmlData, .success) }
            }
        }
    }

    // MARK: - Login Flow V2

    func getLoginFlowV2(serverUrl: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ token: String?, _ endpoint: String?, _ login: String?, _ data: Data?, _ error: NKError) -> Void) {
        let endpoint = "index.php/login/v2"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(nil, nil, nil, nil, .urlError) }
        }
        var headers: HTTPHeaders?
        if let userAgent = options.customUserAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
        }

        sessionManager.request(url, method: .post, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(nil, nil, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)

                let token = json["poll"]["token"].string
                let endpoint = json["poll"]["endpoint"].string
                let login = json["login"].string

                options.queue.async { completion(token, endpoint, login, jsonData, .success) }
            }
        }
    }

    func getLoginFlowV2Poll(token: String,
                            endpoint: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ server: String?, _ loginName: String?, _ appPassword: String?, _ data: Data?, _ error: NKError) -> Void) {
        let serverUrl = endpoint + "?token=" + token
        guard let url = serverUrl.asUrl else {
            return options.queue.async { completion(nil, nil, nil, nil, .urlError) }
        }
        var headers: HTTPHeaders?
        if let userAgent = options.customUserAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
        }

        sessionManager.request(url, method: .post, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(nil, nil, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let server = json["server"].string
                let loginName = json["loginName"].string
                let appPassword = json["appPassword"].string

                options.queue.async { completion(server, loginName, appPassword, jsonData, .success) }
            }
        }
    }
}
