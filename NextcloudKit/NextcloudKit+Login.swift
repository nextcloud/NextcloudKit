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

extension NextcloudKit {
        
    //MARK: - App Password
    
    @objc public func getAppPassword(serverUrl: String, username: String, password: String, userAgent: String? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ token: String?, _ error: NKError) -> Void) {
                
        let endpoint = "ocs/v2.php/core/getapppassword"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            queue.async { completionHandler(nil, .urlError) }
            return
        }
        
        var headers: HTTPHeaders = [.authorization(username: username, password: password)]
        if let userAgent = userAgent {
            headers.update(.userAgent(userAgent))
        }
        headers.update(name: "OCS-APIRequest", value: "true")
               
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "GET"), headers: headers)
        } catch {
            queue.async { completionHandler(nil, NKError(error: error)) }
            return
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(nil, error) }
            case .success(let data):
                if let data = data {
                    let apppassword = NKDataFileXML().convertDataAppPassword(data: data)
                    queue.async { completionHandler(apppassword, .success) }
                } else {
                    queue.async { completionHandler(nil, .xmlError) }
                }
            }
        }
    }
    
    //MARK: - Login Flow V2
    
    @objc public func getLoginFlowV2(serverUrl: String, userAgent: String? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ token: String?, _ endpoint: String? , _ login: String?, _ error: NKError) -> Void) {
                
        let endpoint = "index.php/login/v2"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            queue.async { completionHandler(nil, nil, nil, .urlError) }
            return
        }
        
        var headers: HTTPHeaders?
        if let userAgent = userAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
        }

        sessionManager.request(url, method: .post, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(nil, nil, nil, error) }
            case .success(let json):
                let json = JSON(json)
               
                let token = json["poll"]["token"].string
                let endpoint = json["poll"]["endpoint"].string
                let login = json["login"].string
                
                queue.async { completionHandler(token, endpoint, login, .success) }
            }
        }
    }
    
    @objc public func getLoginFlowV2Poll(token: String, endpoint: String, userAgent: String? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ server: String?, _ loginName: String? , _ appPassword: String?, _ error: NKError) -> Void) {
                
        let serverUrl = endpoint + "?token=" + token
        
        guard let url = serverUrl.asUrl else {
            queue.async { completionHandler(nil, nil, nil, .urlError) }
            return
        }
        
        var headers: HTTPHeaders?
        if let userAgent = userAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
        }
        
        sessionManager.request(url, method: .post, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(nil, nil, nil, error) }
            case .success(let json):
                let json = JSON(json)
            
                let server = json["server"].string
                let loginName = json["loginName"].string
                let appPassword = json["appPassword"].string
                
                queue.async { completionHandler(server, loginName, appPassword, .success) }
            }
        }
    }
}
