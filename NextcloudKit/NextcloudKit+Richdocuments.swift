//
//  NextcloudKit+Richdocuments.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 18/05/2020.
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

    @objc public func createUrlRichdocuments(fileID: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _  url: String?, _ error: NKError) -> Void) {
                
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/richdocuments/api/v1/document?format=json"
        let parameters: [String: Any] = ["fileId": fileID]

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "POST")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
              
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    let url = json["ocs"]["data"]["url"].stringValue
                    queue.async { completionHandler(account, url, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func getTemplatesRichdocuments(typeTemplate: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ templates: [NKRichdocumentsTemplate]?, _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/richdocuments/api/v1/templates/" + typeTemplate + "?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
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
                let data = json["ocs"]["data"].arrayValue
                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    var templates: [NKRichdocumentsTemplate] = []
                    for templateJSON in data {
                        let template = NKRichdocumentsTemplate()

                        template.delete = templateJSON["delete"].stringValue
                        template.templateId = templateJSON["id"].intValue
                        template.ext = templateJSON["extension"].stringValue
                        template.name = templateJSON["name"].stringValue
                        template.preview = templateJSON["preview"].stringValue
                        template.type = templateJSON["type"].stringValue

                        templates.append(template)
                    }
                    queue.async { completionHandler(account, templates, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func createRichdocuments(path: String, templateId: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _  url: String?, _ error: NKError) -> Void) {
                
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/richdocuments/api/v1/templates/new?format=json"
        let parameters: [String: Any] = ["path": path, "template": templateId]
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "POST")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
                
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    let url = json["ocs"]["data"]["url"].stringValue
                    queue.async { completionHandler(account, url, .success) }
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func createAssetRichdocuments(path: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _  url: String?, _ error: NKError) -> Void) {
                
        let account = NKCommon.shared.account
        let endpoint = "index.php/apps/richdocuments/assets?format=json"
        let parameters: [String: Any] = ["path": path]

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "POST")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
                
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let url = json["url"].string
                queue.async { completionHandler(account, url, .success) }
            }
        }
    }
}
