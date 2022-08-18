//
//  NextcloudKit+NCText.swift
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

    @objc public func NCTextObtainEditorDetails(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _  editors: [NKEditorDetailsEditors], _ creators: [NKEditorDetailsCreators], _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account
        var editors: [NKEditorDetailsEditors] = []
        var creators: [NKEditorDetailsCreators] = []

        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, editors, creators, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, editors, creators, error) }
            case .success(let json):
                let json = JSON(json)
                let ocsdataeditors = json["ocs"]["data"]["editors"]
                for (_, subJson):(String, JSON) in ocsdataeditors {
                    let editor = NKEditorDetailsEditors()
                    
                    if let mimetypes = subJson["mimetypes"].array {
                        for mimetype in mimetypes {
                            editor.mimetypes.append(mimetype.stringValue)
                        }
                    }
                    editor.name = subJson["name"].stringValue
                    if let optionalMimetypes = subJson["optionalMimetypes"].array {
                        for optionalMimetype in optionalMimetypes {
                            editor.optionalMimetypes.append(optionalMimetype.stringValue)
                        }
                    }
                    editor.secure = subJson["secure"].intValue
                    editors.append(editor)
                }
                
                let ocsdatacreators = json["ocs"]["data"]["creators"]
                for (_, subJson):(String, JSON) in ocsdatacreators {
                    let creator = NKEditorDetailsCreators()

                    creator.editor = subJson["editor"].stringValue
                    creator.ext = subJson["extension"].stringValue
                    creator.identifier = subJson["id"].stringValue
                    creator.mimetype = subJson["mimetype"].stringValue
                    creator.name = subJson["name"].stringValue
                    creator.templates = subJson["templates"].intValue

                    creators.append(creator)
                }
                
                queue.async { completionHandler(account, editors, creators, .success) }
            }
        }
    }
    
    @objc public func NCTextOpenFile(fileNamePath: String, editor: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _  url: String?, _ error: NKError) -> Void) {
                
        let account = NKCommon.shared.account

        guard let fileNamePath = fileNamePath.urlEncoded else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }
        
        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/open?path=/" + fileNamePath + "&editorId=" + editor + "&format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "POST")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
    
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let url = json["ocs"]["data"]["url"].stringValue
                queue.async { completionHandler(account, url, .success) }
            }
        }
    }
    
    @objc public func NCTextGetListOfTemplates(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _  templates: [NKEditorTemplates], _ error: NKError) -> Void) {
                
        let account = NKCommon.shared.account
        var templates: [NKEditorTemplates] = []

        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/templates/text/textdocumenttemplate?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, templates, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, templates, error) }
            case .success(let json):
                let json = JSON(json)
                let ocsdatatemplates = json["ocs"]["data"]["editors"]
                
                for (_, subJson):(String, JSON) in ocsdatatemplates {
                    let template = NKEditorTemplates()
                    
                    template.ext = subJson["extension"].stringValue
                    template.identifier = subJson["id"].stringValue
                    template.name = subJson["name"].stringValue
                    template.preview = subJson["preview"].stringValue
                    
                    templates.append(template)
                }
                
                queue.async { completionHandler(account, templates, .success) }
            }
        }
    }
    
    @objc public func NCTextCreateFile(fileNamePath: String, editorId: String, creatorId: String, templateId: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ url: String?, _ error: NKError) -> Void) {
                
        let account = NKCommon.shared.account

        guard let fileNamePath = fileNamePath.urlEncoded else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }
        
        var endpoint = ""
        
        if templateId == "" {
            endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/create?path=/" + fileNamePath + "&editorId=" + editorId + "&creatorId=" + creatorId + "&format=json"
        } else {
            endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/create?path=/" + fileNamePath + "&editorId=" + editorId + "&creatorId=" + creatorId + "&templateId=" + templateId + "&format=json"
        }
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            queue.async { completionHandler(account, nil, .urlError) }
            return
        }
        
        let method = HTTPMethod(rawValue: "POST")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let url = json["ocs"]["data"]["url"].stringValue
                queue.async { completionHandler(account, url, .success) }
            }
        }
    }
}
