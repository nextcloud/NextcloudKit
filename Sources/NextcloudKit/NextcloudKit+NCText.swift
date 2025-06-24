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
                                 completion: @escaping (_ account: String, _  editors: [NKEditorDetailsEditor]?, _ creators: [NKEditorDetailsCreator]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, response, error) }
            case .success(let responseData):
                Task {
                    do {
                        let (editors, creators) = try NKEditorDetailsConverter.from(data: responseData)
                        let capabilities = await NKCapabilities.shared.getCapabilitiesAsync(for: account)
                        capabilities.directEditingEditors = editors
                        capabilities.directEditingCreators = creators
                        await NKCapabilities.shared.appendCapabilitiesAsync(for: account, capabilities: capabilities)

                        options.queue.async {
                            completion(account, editors, creators, response, .success)
                        }

                    } catch {
                        nkLog(error: "Parsing error in NKEditorDetailsConverter: \(error)")
                        options.queue.async {
                            completion(account, nil, nil, response, .invalidData)
                        }
                    }
                }
            }
        }
    }

    func textObtainEditorDetailsAsync(account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, editors: [NKEditorDetailsEditor]?, creators: [NKEditorDetailsCreator]?, responseData: AFDataResponse<Data>?, error: NKError) {
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
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .post, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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
                                completion: @escaping (_ account: String, _ templates: [NKEditorTemplate]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/templates/text/textdocumenttemplate"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let data):
                Task {
                    do {
                        let decoded = try JSONDecoder().decode(NKEditorTemplateResponse.self, from: data)
                        let templates = decoded.ocs.data.editors
                        // Update capabilities
                        let capabilities = await NKCapabilities.shared.getCapabilitiesAsync(for: account)
                        capabilities.directEditingTemplates = templates
                        await NKCapabilities.shared.appendCapabilitiesAsync(for: account, capabilities: capabilities)
                        
                        options.queue.async { completion(account, templates, response, .success) }
                    } catch {
                        nkLog(error: "Failed to decode template list: \(error)")
                        options.queue.async { completion(account, nil, response, .invalidData) }
                    }
                }
            }
        }
    }

    func textGetListOfTemplatesAsync(account: String,
                                     options: NKRequestOptions = NKRequestOptions()) async -> (account: String, templates: [NKEditorTemplate]?, responseData: AFDataResponse<Data>?, error: NKError) {
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
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .post, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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
