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

    @objc public func NCTextObtainEditorDetails(options: NKRequestOptions = NKRequestOptions(),
                                                completion: @escaping (_ account: String, _  editors: [NKEditorDetailsEditors], _ creators: [NKEditorDetailsCreators], _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing"

        var editors: [NKEditorDetailsEditors] = []
        var creators: [NKEditorDetailsCreators] = []

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, editors, creators, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, editors, creators, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let ocsdataeditors = json["ocs"]["data"]["editors"]
                for (_, subJson): (String, JSON) in ocsdataeditors {
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
                for (_, subJson): (String, JSON) in ocsdatacreators {
                    let creator = NKEditorDetailsCreators()

                    creator.editor = subJson["editor"].stringValue
                    creator.ext = subJson["extension"].stringValue
                    creator.identifier = subJson["id"].stringValue
                    creator.mimetype = subJson["mimetype"].stringValue
                    creator.name = subJson["name"].stringValue
                    creator.templates = subJson["templates"].intValue

                    creators.append(creator)
                }

                options.queue.async { completion(account, editors, creators, jsonData, .success) }
            }
        }
    }

    @objc public func NCTextOpenFile(fileNamePath: String,
                                     fileId: String? = nil,
                                     editor: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     completion: @escaping (_ account: String, _  url: String?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        guard let fileNamePath = fileNamePath.urlEncoded else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        var endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/open?path=/\(fileNamePath)&editorId=\(editor)"
        if let fileId = fileId {
            endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/open?path=/\(fileNamePath)&fileId=\(fileId)&editorId=\(editor)"
        }

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .post, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let url = json["ocs"]["data"]["url"].stringValue
                options.queue.async { completion(account, url, jsonData, .success) }
            }
        }
    }

    @objc public func NCTextGetListOfTemplates(options: NKRequestOptions = NKRequestOptions(),
                                               completion: @escaping (_ account: String, _  templates: [NKEditorTemplates], _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/templates/text/textdocumenttemplate"

        var templates: [NKEditorTemplates] = []

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, templates, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, templates, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let ocsdatatemplates = json["ocs"]["data"]["editors"]

                for (_, subJson): (String, JSON) in ocsdatatemplates {
                    let template = NKEditorTemplates()

                    template.ext = subJson["extension"].stringValue
                    template.identifier = subJson["id"].stringValue
                    template.name = subJson["name"].stringValue
                    template.preview = subJson["preview"].stringValue

                    templates.append(template)
                }

                options.queue.async { completion(account, templates, jsonData, .success) }
            }
        }
    }

    @objc public func NCTextCreateFile(fileNamePath: String,
                                       editorId: String,
                                       creatorId: String,
                                       templateId: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       completion: @escaping (_ account: String, _ url: String?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        guard let fileNamePath = fileNamePath.urlEncoded else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        var endpoint = ""

        if templateId.isEmpty {
            endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/create?path=/\(fileNamePath)&editorId=\(editorId)&creatorId=\(creatorId)"
        } else {
            endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/create?path=/\(fileNamePath)&editorId=\(editorId)&creatorId=\(creatorId)&templateId=\(templateId)"
        }

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .post, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let url = json["ocs"]["data"]["url"].stringValue
                options.queue.async { completion(account, url, jsonData, .success) }
            }
        }
    }
}
