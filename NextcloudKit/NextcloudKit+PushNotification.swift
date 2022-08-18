//
//  NextcloudKit+PushNotification.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 22/05/2020.
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

extension NextcloudKit {

    @objc public func subscribingPushNotification(serverUrl: String, account: String, user: String, password: String, pushTokenHash: String, devicePublicKey: String, proxyServerUrl: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ deviceIdentifier: String?, _ signature: String?, _ publicKey: String?, _ error: NKError) -> Void) {
        
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/push?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, nil, nil, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "POST")
        
        let parameters = [
            "pushTokenHash": pushTokenHash,
            "devicePublicKey": devicePublicKey,
            "proxyServer": proxyServerUrl,
        ]
        
        let headers = NKCommon.shared.getStandardHeaders(user: user, password: password, appendHeaders: addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters:parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, nil, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode  {
                    let deviceIdentifier = json["ocs"]["data"]["deviceIdentifier"].stringValue
                    let signature = json["ocs"]["data"]["signature"].stringValue
                    let publicKey = json["ocs"]["data"]["publicKey"].stringValue
                    queue.async { completionHandler(account, deviceIdentifier, signature, publicKey, .success) }
                } else {
                    queue.async { completionHandler(account, nil, nil, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func unsubscribingPushNotification(serverUrl: String, account: String, user: String, password: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
                            
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/push"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            queue.async { completionHandler(account, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "DELETE")
        
        let headers = NKCommon.shared.getStandardHeaders(user: user, password: password, appendHeaders: addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
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
    
    @objc public func subscribingPushProxy(proxyServerUrl: String, pushToken: String, deviceIdentifier: String, signature: String, publicKey: String, userAgent: String, queue: DispatchQueue = .main, completionHandler: @escaping (_ error: NKError) -> Void) {
        
        let endpoint = "devices?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: proxyServerUrl, endpoint: endpoint) else {
            queue.async { completionHandler(.urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "POST")
        
        let parameters = [
            "pushToken": pushToken,
            "deviceIdentifier": deviceIdentifier,
            "deviceIdentifierSignature": signature,
            "userPublicKey": publicKey
        ]
        
        let headers = HTTPHeaders.init(arrayLiteral: .userAgent(userAgent))
                
        sessionManager.request(url, method: method, parameters:parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(error) }
            case .success( _):
                queue.async { completionHandler(.success) }
            }
        }
    }
    
    @objc public func unsubscribingPushProxy(proxyServerUrl: String, deviceIdentifier: String, signature: String, publicKey: String, userAgent: String, queue: DispatchQueue = .main, completionHandler: @escaping (_ error: NKError) -> Void) {
                
        let endpoint = "devices"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: proxyServerUrl, endpoint: endpoint) else {
            queue.async { completionHandler(.urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "DELETE")
        
        let parameters = [
            "deviceIdentifier": deviceIdentifier,
            "deviceIdentifierSignature": signature,
            "userPublicKey": publicKey
        ]
        
        let headers = HTTPHeaders.init(arrayLiteral: .userAgent(userAgent))
        
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(error) }
            case .success( _):
                queue.async { completionHandler(.success) }
            }
        }
    }
}

