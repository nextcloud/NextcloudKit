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

    @objc public func markE2EEFolder(fileId: String, delete: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
                            
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/encrypted/\(fileId)"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, .urlError) }
            return
        }

        let method: HTTPMethod = delete ? .delete : .put
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)

        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    queue.async { completionHandler(account, .success) }
                } else {
                    queue.async { completionHandler(account, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func lockE2EEFolder(fileId: String, e2eToken: String?, method: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ e2eToken: String?, _ error: NKError) -> Void) {
                            
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/lock/\(fileId)"
        var parameters: [String: Any] = [:]
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: method)
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent, e2eToken: e2eToken)
        if e2eToken != nil {
            parameters = ["e2e-token": e2eToken!]
        }

        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let e2eToken = json["ocs"]["data"]["e2e-token"].string
                    queue.async { completionHandler(account, e2eToken, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func getE2EEMetadata(fileId: String, e2eToken: String?, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ e2eMetadata: String?, _ error: NKError) -> Void) {
                            
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/meta-data/\(fileId)"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent, e2eToken: e2eToken)
        
        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let e2eMetadata = json["ocs"]["data"]["meta-data"].string
                    queue.async { completionHandler(account, e2eMetadata, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func putE2EEMetadata(fileId: String, e2eToken: String, e2eMetadata: String?, method: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ metadata: String?, _ error: NKError) -> Void) {
                            
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/meta-data/\(fileId)"
        var parameters: [String: Any] = [:]

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent, e2eToken: e2eToken)
        let method = HTTPMethod(rawValue: method)
        
        if e2eMetadata != nil {
            parameters = ["metaData": e2eMetadata!, "e2e-token":e2eToken]
        }
       
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let metadata = json["ocs"]["data"]["meta-data"].string
                    queue.async { completionHandler(account, metadata, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    //MARK: -

    @objc public func getE2EECertificate(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ certificate: String?, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/public-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
           
        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let userId = NKCommon.shared.userId
                    let key = json["ocs"]["data"]["public-keys"][userId].stringValue
                    queue.async { completionHandler(account, key, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func getE2EEPrivateKey(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ privateKey: String?, _ error: NKError) -> Void) {
                           
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/private-key"
       
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
       
        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                    let error = NKError(error: error, afResponse: response)
                    queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let key = json["ocs"]["data"]["private-key"].stringValue
                    queue.async { completionHandler(account, key, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func getE2EEPublicKey(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ publicKey: String?, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/server-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
           
        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let key = json["ocs"]["data"]["public-key"].stringValue
                    queue.async { completionHandler(account, key, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func signE2EECertificate(certificate: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ certificate: String?, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/public-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        let parameters = ["csr": certificate]
        
        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["public-key"].stringValue
                    print(key)
                    queue.async { completionHandler(account, key, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func storeE2EEPrivateKey(privateKey: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ privateKey: String?, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/private-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
           
        let parameters = ["privateKey": privateKey]
        
        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["private-key"].stringValue
                    queue.async { completionHandler(account, key, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func deleteE2EECertificate(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/public-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, .urlError) }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
         
        sessionManager.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success( _):
                queue.async { completionHandler(account, .success) }
            }
        }
    }
    
    @objc public func deleteE2EEPrivateKey(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
                               
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/v1/private-key"
           
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, .urlError) }
            return
        }
                      
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
           
        sessionManager.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success( _):
                queue.async { completionHandler(account, .success) }
            }
        }
    }
}
