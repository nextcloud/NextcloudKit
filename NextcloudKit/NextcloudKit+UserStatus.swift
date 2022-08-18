//
//  NextcloudKit+UserStatus.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 22/11/20.
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
    
    @objc public func getUserStatus(userId: String? = nil, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ clearAt: NSDate?, _ icon: String?, _ message: String?, _ messageId: String?, _ messageIsPredefined: Bool, _ status: String?, _ statusIsUserDefined: Bool, _ userId: String?, _ error: NKError) -> Void) {
    
        let account = NKCommon.shared.account
        var endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status?format=json"
        if let userId = userId {
            endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/" + userId + "?format=json"
        }
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, nil, nil, nil, false, nil, false, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, nil, nil, nil, false, nil, false, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    
                    var clearAt: NSDate?
                    if let clearAtDouble = json["ocs"]["data"]["clearAt"].double {
                        clearAt = Date(timeIntervalSince1970: clearAtDouble) as NSDate
                    }
                    let icon = json["ocs"]["data"]["icon"].string
                    let message = json["ocs"]["data"]["message"].string
                    let messageId = json["ocs"]["data"]["messageId"].string
                    let messageIsPredefined = json["ocs"]["data"]["messageIsPredefined"].boolValue
                    let status = json["ocs"]["data"]["status"].string
                    let statusIsUserDefined = json["ocs"]["data"]["statusIsUserDefined"].boolValue
                    let userId = json["ocs"]["data"]["userId"].string

                    queue.async { completionHandler(account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, userId, .success) }
                } else {
                    queue.async { completionHandler(account, nil, nil, nil, nil, false, nil, false, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func setUserStatus(status: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
           
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/status?format=json"

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "PUT")
             
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)

        let parameters = [
            "statusType": String(status)
        ]
                
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success(let json):
                let json = JSON(json)
                
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    queue.async { completionHandler(account, .success) }
                }  else {
                    queue.async { completionHandler(account, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func setCustomMessagePredefined(messageId: String, clearAt: Double, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
           
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message/predefined?format=json"

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "PUT")
             
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)

        var parameters = [
            "messageId": String(messageId)
        ]
        if clearAt > 0 {
            parameters["clearAt"] = String(clearAt)
        }
                
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success(let json):
                let json = JSON(json)
                
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    queue.async { completionHandler(account, .success) }
                }  else {
                    queue.async { completionHandler(account, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func setCustomMessageUserDefined(statusIcon: String?, message: String, clearAt: Double, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
           
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message/custom?format=json"

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "PUT")
             
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)

        var parameters = [
            "message": String(message)
        ]
        if statusIcon != nil {
            parameters["statusIcon"] = statusIcon
        }
        if clearAt > 0 {
            parameters["clearAt"] = String(clearAt)
        }
                
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success(let json):
                let json = JSON(json)
                
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    queue.async { completionHandler(account, .success) }
                }  else {
                    queue.async { completionHandler(account, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func clearMessage(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
           
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/user_status/message?format=json"

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "DELETE")
             
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
                if statusCode == 200 {
                    queue.async { completionHandler(account, .success) }
                }  else {
                    queue.async { completionHandler(account, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func getUserStatusPredefinedStatuses(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ userStatuses: [NKUserStatus]?, _ error: NKError) -> Void) {
    
        let account = NKCommon.shared.account
        var userStatuses: [NKUserStatus] = []
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/predefined_statuses?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    
                    let ocsdata = json["ocs"]["data"]
                    for (_, subJson):(String, JSON) in ocsdata {
                        let userStatus = NKUserStatus()
                    
                        if let value = subJson["clearAt"]["time"].int {
                            userStatus.clearAtTime = String(value)
                        } else if let value = subJson["clearAt"]["time"].string {
                            userStatus.clearAtTime = value
                        }
                        userStatus.clearAtType = subJson["clearAt"]["type"].string
                        userStatus.icon = subJson["icon"].string
                        userStatus.id = subJson["id"].string
                        userStatus.message = subJson["message"].string
                        userStatus.predefined = true

                        userStatuses.append(userStatus)
                    }
                
                    queue.async { completionHandler(account, userStatuses, .success) }
                }  else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func getUserStatusRetrieveStatuses(limit: Int, offset: Int, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ userStatuses: [NKUserStatus]?, _ error: NKError) -> Void) {
    
        let account = NKCommon.shared.account
        var userStatuses: [NKUserStatus] = []
        let endpoint = "ocs/v2.php/apps/user_status/api/v1/statuses?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        let parameters = [
            "limit": String(limit),
            "offset": String(offset)
        ]
        
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    
                    let ocsdata = json["ocs"]["data"]
                    for (_, subJson):(String, JSON) in ocsdata {
                        let userStatus = NKUserStatus()
                    
                        if let value = subJson["clearAt"].double {
                            if value > 0 {
                                userStatus.clearAt = NSDate(timeIntervalSince1970: value)
                            }
                        }
                        userStatus.icon = subJson["icon"].string
                        userStatus.message = subJson["message"].string
                        userStatus.predefined = false
                        userStatus.userId = subJson["userId"].string
                        
                        userStatuses.append(userStatus)
                    }
                
                    queue.async { completionHandler(account, userStatuses, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
}
