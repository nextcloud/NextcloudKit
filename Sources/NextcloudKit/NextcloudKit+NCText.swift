// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func textObtainEditorDetails(account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                 completion: @escaping (_ account: String, _  editors: [NKEditorDetailsEditors], _ creators: [NKEditorDetailsCreators], _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing"
        var editors: [NKEditorDetailsEditors] = []
        var creators: [NKEditorDetailsCreators] = []
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, editors, creators, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, editors, creators, response, error) }
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

                options.queue.async { completion(account, editors, creators, response, .success) }
            }
        }
    }

    func textObtainEditorDetailsAsync(account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, editors: [NKEditorDetailsEditors], creators: [NKEditorDetailsCreators], responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation { continuation in
            textObtainEditorDetails(account: account,
                                    options: options,
                                    taskHandler: taskHandler) { account, editors, creators, responseData, error in
                continuation.resume(returning: (account, editors, creators, responseData, error))
            }
        }
    }

    func textOpenFile(fileNamePath: String,
                      fileId: String? = nil,
                      editor: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _  url: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let fileNamePath = fileNamePath.urlEncoded else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        var endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/open?path=/\(fileNamePath)&editorId=\(editor)"
        if let fileId = fileId {
            endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/open?path=/\(fileNamePath)&fileId=\(fileId)&editorId=\(editor)"
        }
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .post, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let url = json["ocs"]["data"]["url"].stringValue
                options.queue.async { completion(account, url, response, .success) }
            }
        }
    }

    func textGetListOfTemplates(account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ templates: [NKEditorTemplates]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/templates/text/textdocumenttemplate"
        var templates: [NKEditorTemplates] = []
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, templates, response, error) }
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

                options.queue.async { completion(account, templates, response, .success) }
            }
        }
    }

    func textGetListOfTemplatesAsync(account: String,
                                     options: NKRequestOptions = NKRequestOptions()) async -> (account: String, templates: [NKEditorTemplates]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            textGetListOfTemplates(account: account) { account, templates, responseData, error in
                continuation.resume(returning: (account: account, templates: templates, responseData: responseData, error: error))
            }
        })
    }

    func textCreateFile(fileNamePath: String,
                        editorId: String,
                        creatorId: String,
                        templateId: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ url: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let fileNamePath = fileNamePath.urlEncoded else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        var endpoint = ""
        if templateId.isEmpty {
            endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/create?path=/\(fileNamePath)&editorId=\(editorId)&creatorId=\(creatorId)"
        } else {
            endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/create?path=/\(fileNamePath)&editorId=\(editorId)&creatorId=\(creatorId)&templateId=\(templateId)"
        }
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .post, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let url = json["ocs"]["data"]["url"].stringValue
                options.queue.async { completion(account, url, response, .success) }
            }
        }
    }
}
