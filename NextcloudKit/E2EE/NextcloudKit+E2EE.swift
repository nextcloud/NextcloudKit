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

extension NextcloudKit {

    @objc public func markE2EEFolder(fileId: String,
                                     delete: Bool,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
                            
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/encrypted/\(fileId)"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, .urlError) }
        }

        let method: HTTPMethod = delete ? .delete : .put

        let headers = NKCommon.shared.getStandardHeaders(options: options)

        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    options.queue.async { completionHandler(account, .success) }
                } else {
                    options.queue.async { completionHandler(account, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    ///
    /// - Parameters:
    ///     - fileId: the nextcloud fileId
    ///     - method: POST / DELETE
    ///     - optionsE2EE.e2eToken: e2eToken
    ///
    @objc public func lockE2EEFolder(fileId: String,
                                     method: String,
                                     optionsE2EE: NKRequestOptionsE2EE,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     completionHandler: @escaping (_ account: String, _ e2eToken: String?, _ data: Data?, _ error: NKError) -> Void) {
                            
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/lock/\(fileId)"

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, nil, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: method)

        let headers = NKCommon.shared.getStandardHeaders(options: options, optionsE2EE: optionsE2EE)

        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let e2eToken = json["ocs"]["data"]["e2e-token"].string
                    options.queue.async { completionHandler(account, e2eToken, jsonData, .success) }
                } else {
                    options.queue.async { completionHandler(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    ///
    /// - Parameters:
    ///     - fileId: the nextcloud fileId
    ///     - optionsE2EE.e2eToken: e2eToken
    ///
    @objc public func getE2EEMetadata(fileId: String,
                                      optionsE2EE: NKRequestOptionsE2EE,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      completionHandler: @escaping (_ account: String, _ e2eMetadata: String?, _ data: Data?, _ error: NKError) -> Void) {
                            
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/meta-data/\(fileId)"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, nil, nil, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options, optionsE2EE: optionsE2EE)
        
        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let e2eMetadata = json["ocs"]["data"]["meta-data"].string
                    options.queue.async { completionHandler(account, e2eMetadata, jsonData, .success) }
                } else {
                    options.queue.async { completionHandler(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    ///
    /// - Parameters:
    ///     - fileId: the nextcloud fileId
    ///     - method: POST / PUT / DELETE
    ///     - optionsE2EE.e2eToken: e2eToken
    ///     - optionsE2EE.e2eMetadata: e2eMetadata (optional)
    ///
    @objc public func putE2EEMetadata(fileId: String,
                                      method: String,
                                      optionsE2EE: NKRequestOptionsE2EE,
                                      options: NKRequestOptions = NKRequestOptions(), completionHandler: @escaping (_ account: String, _ metadata: String?, _ data: Data?, _ error: NKError) -> Void) {
                            
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/meta-data/\(fileId)"

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, nil, nil, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options, optionsE2EE: optionsE2EE)

        let method = HTTPMethod(rawValue: method)

        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let metadata = json["ocs"]["data"]["meta-data"].string
                    options.queue.async { completionHandler(account, metadata, jsonData, .success) }
                } else {
                    options.queue.async { completionHandler(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    //MARK: -

    @objc public func getE2EECertificate(options: NKRequestOptions = NKRequestOptions(), completionHandler: @escaping (_ account: String, _ certificate: String?, _ data: Data?, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/public-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, nil, nil, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options)
           
        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let userId = NKCommon.shared.userId
                    let key = json["ocs"]["data"]["public-keys"][userId].stringValue
                    options.queue.async { completionHandler(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completionHandler(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    @objc public func getE2EEPrivateKey(options: NKRequestOptions = NKRequestOptions(), completionHandler: @escaping (_ account: String, _ privateKey: String?, _ data: Data?, _ error: NKError) -> Void) {
                           
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/private-key"
       
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, nil, nil, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options)
       
        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                    let error = NKError(error: error, afResponse: response)
                    options.queue.async { completionHandler(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let key = json["ocs"]["data"]["private-key"].stringValue
                    options.queue.async { completionHandler(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completionHandler(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func getE2EEPublicKey(options: NKRequestOptions = NKRequestOptions(), completionHandler: @escaping (_ account: String, _ publicKey: String?, _ data: Data?, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/server-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, nil, nil, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options)
           
        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let key = json["ocs"]["data"]["public-key"].stringValue
                    options.queue.async { completionHandler(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completionHandler(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    ///
    /// - Parameters:
    ///     - optionsE2EE.csr: csr
    ///
    @objc public func signE2EECertificate(optionsE2EE: NKRequestOptionsE2EE,
                                          options: NKRequestOptions = NKRequestOptions(), completionHandler: @escaping (_ account: String, _ certificate: String?, _ data: Data?, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/public-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, nil, nil, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options)

        sessionManager.request(url, method: .post, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["public-key"].stringValue
                    print(key)
                    options.queue.async { completionHandler(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completionHandler(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    ///
    /// - Parameters:
    ///     - optionsE2EE.privateKey: privateKey
    ///
    @objc public func storeE2EEPrivateKey(optionsE2EE: NKRequestOptionsE2EE,
                                          options: NKRequestOptions = NKRequestOptions(), completionHandler: @escaping (_ account: String, _ privateKey: String?, _ data: Data?, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/private-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, nil, nil, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options)

        sessionManager.request(url, method: .post, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["private-key"].stringValue
                    options.queue.async { completionHandler(account, key, jsonData, .success) }
                } else {
                    options.queue.async { completionHandler(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    @objc public func deleteE2EECertificate(options: NKRequestOptions = NKRequestOptions(), completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account

        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/public-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options)
         
        sessionManager.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, error) }
            case .success( _):
                options.queue.async { completionHandler(account, .success) }
            }
        }
    }

    @objc public func deleteE2EEPrivateKey(options: NKRequestOptions = NKRequestOptions(), completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account
        
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/private-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return options.queue.async { completionHandler(account, .urlError) }
        }
                      
        let headers = NKCommon.shared.getStandardHeaders(options: options)
           
        sessionManager.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completionHandler(account, error) }
            case .success( _):
                options.queue.async { completionHandler(account, .success) }
            }
        }
    }
}
