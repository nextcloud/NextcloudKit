//
//  NextcloudKit+E2EE.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 22/05/2020.
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
import SwiftyJSON

public extension NextcloudKit {
    func markE2EEFolder(fileId: String,
                        delete: Bool,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/encrypted/\(fileId)"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, .urlError) }
        }
        let method: HTTPMethod = delete ? .delete : .put
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    options.queue.async { completion(account, .success) }
                } else {
                    options.queue.async { completion(account, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func lockE2EEFolder(fileId: String,
                        e2eToken: String?,
                        e2eCounter: String?,
                        method: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ e2eToken: String?, _ data: Data?, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/lock/\(fileId)"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: method)
        var headers = self.nkCommonInstance.getStandardHeaders(options: options)
        var parameters: [String: Any] = [:]

        if let e2eToken {
            headers.update(name: "e2e-token", value: e2eToken)
            parameters = ["e2e-token": e2eToken]
        }
        if let e2eCounter {
            headers.update(name: "X-NC-E2EE-COUNTER", value: e2eCounter)
        }

        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let e2eToken = json["ocs"]["data"]["e2e-token"].string
                    options.queue.async { completion(account, e2eToken, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func getE2EEMetadata(fileId: String,
                         e2eToken: String?,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ e2eMetadata: String?, _ signature: String?, _ data: Data?, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/meta-data/\(fileId)"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)
        var parameters: [String: Any] = [:]

        if let e2eToken {
            parameters["e2e-token"] = e2eToken
        }

        sessionManager.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let e2eMetadata = json["ocs"]["data"]["meta-data"].string
                    let signature = response.response?.allHeaderFields["X-NC-E2EE-SIGNATURE"] as? String
                    options.queue.async { completion(account, e2eMetadata, signature, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func putE2EEMetadata(fileId: String,
                         e2eToken: String,
                         e2eMetadata: String?,
                         signature: String?,
                         method: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ metadata: String?, _ data: Data?, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/meta-data/\(fileId)"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: method)
        var headers = self.nkCommonInstance.getStandardHeaders(options: options)
        var parameters: [String: Any] = [:]

        parameters["e2e-token"] = e2eToken
        headers.update(name: "e2e-token", value: e2eToken)

        if let e2eMetadata {
            parameters["metaData"] = e2eMetadata
        }
        if let signature {
            headers.update(name: "X-NC-E2EE-SIGNATURE", value: signature)
        }

        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                return options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let metadata = json["ocs"]["data"]["meta-data"].string
                    options.queue.async { completion(account, metadata, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    // MARK: -

    func getE2EECertificate(user: String? = nil,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ certificate: String?, _ certificateUser: String?, _ data: Data?, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        let userId = self.nkCommonInstance.userId
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        var endpoint = ""
        if let user = user {
            guard let users = ("[\"" + user + "\"]").urlEncoded else {
                return options.queue.async { completion(account, nil, nil, nil, .urlError) }
            }
            endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/public-key?users=" + users
        } else {
            endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/public-key"
        }
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["public-keys"][userId].stringValue
                    if let user = user {
                        let keyUser = json["ocs"]["data"]["public-keys"][user].string
                        options.queue.async { completion(account, key, keyUser, jsonData, .success) }
                    } else {
                        options.queue.async { completion(account, key, nil, jsonData, .success) }
                    }
                } else {
                    options.queue.async { completion(account, nil, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func getE2EEPrivateKey(options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ privateKey: String?, _ data: Data?, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/private-key"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["private-key"].stringValue
                    options.queue.async { completion(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func getE2EEPublicKey(options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ publicKey: String?, _ data: Data?, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/server-key"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["public-key"].stringValue
                    options.queue.async { completion(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func signE2EECertificate(certificate: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ certificate: String?, _ data: Data?, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/public-key"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)
        let parameters = ["csr": certificate]

        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["public-key"].stringValue
                    print(key)
                    options.queue.async { completion(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func storeE2EEPrivateKey(privateKey: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ privateKey: String?, _ data: Data?, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/private-key"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)
        let parameters = ["privateKey": privateKey]

        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["private-key"].stringValue
                    options.queue.async { completion(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func deleteE2EECertificate(options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                               completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/public-key"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
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

    func deleteE2EEPrivateKey(options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                              completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/private-key"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
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
}
