// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Retrieves the list of editors and creators for collaborative text editing.
    ///
    /// Parameters:
    /// - account: The account from which to fetch the editor details.
    /// - options: Optional request configuration such as headers, queue, or API version.
    /// - taskHandler: Callback to track the underlying URLSessionTask.
    /// - completion: Returns the account, array of editors, array of creators, the raw response data, and NKError.
    func textObtainEditorDetails(account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                 completion: @escaping (_ account: String, _  editors: [NKEditorDetailsEditor]?, _ creators: [NKEditorDetailsCreator]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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
                        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
                        capabilities.directEditingEditors = editors
                        capabilities.directEditingCreators = creators
                        await NKCapabilities.shared.setCapabilities(for: account, capabilities: capabilities)

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

    /// Asynchronously retrieves details of users involved in collaborative editing (editors and creators).
    ///
    /// - Parameters:
    ///   - account: The Nextcloud account from which the information is retrieved.
    ///   - options: Configuration for the request, including headers and execution queue.
    ///   - taskHandler: Optional callback to monitor the underlying network task.
    /// - Returns: A tuple containing the account, list of editors, list of creators, raw response, and NKError.
    func textObtainEditorDetailsAsync(account: String,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        editors: [NKEditorDetailsEditor]?,
        creators: [NKEditorDetailsCreator]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textObtainEditorDetails(account: account,
                                    options: options,
                                    taskHandler: taskHandler) { account, editors, creators, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    editors: editors,
                    creators: creators,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Opens a file using the specified text editor and returns the access URL.
    ///
    /// Parameters:
    /// - fileNamePath: The path of the file to open on the server.
    /// - fileId: Optional file identifier used to reference the file more precisely.
    /// - editor: The identifier of the text editor to use.
    /// - account: The account initiating the file open request.
    /// - options: Optional configuration for the request (headers, API version, etc.).
    /// - taskHandler: Callback triggered with the underlying URLSessionTask.
    /// - completion: Returns the account, the resulting file editor URL, raw response data, and an NKError.
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
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

    /// Asynchronously opens a file in the specified text editor and retrieves the access URL.
    ///
    /// - Parameters:
    ///   - fileNamePath: Path of the file on the server.
    ///   - fileId: Optional file ID to assist in uniquely identifying the file.
    ///   - editor: Identifier of the text editor to be used.
    ///   - account: Account performing the operation.
    ///   - options: Configuration options for the request.
    ///   - taskHandler: Optional monitoring for the underlying URLSessionTask.
    /// - Returns: A tuple containing the account, resulting URL, raw response data, and NKError.
    func textOpenFileAsync(fileNamePath: String,
                           fileId: String? = nil,
                           editor: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        url: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textOpenFile(fileNamePath: fileNamePath,
                         fileId: fileId,
                         editor: editor,
                         account: account,
                         options: options,
                         taskHandler: taskHandler) { account, url, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    url: url,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Retrieves the list of available editor templates for the given account.
    ///
    /// Parameters:
    /// - account: The account requesting the list of templates.
    /// - options: Optional request configuration such as headers, queue, or API version.
    /// - taskHandler: Callback triggered with the underlying URLSessionTask.
    /// - completion: Returns the account, an optional array of NKEditorTemplate, the raw response, and an NKError.
    func textGetListOfTemplates(account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ templates: [NKEditorTemplate]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files/api/v1/directEditing/templates/text/textdocumenttemplate"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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
                        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
                        capabilities.directEditingTemplates = templates
                        await NKCapabilities.shared.setCapabilities(for: account, capabilities: capabilities)

                        options.queue.async { completion(account, templates, response, .success) }
                    } catch {
                        nkLog(error: "Failed to decode template list: \(error)")
                        options.queue.async { completion(account, nil, response, .invalidData) }
                    }
                }
            }
        }
    }

    /// Asynchronously retrieves a list of editor templates for the specified account.
    ///
    /// - Parameters:
    ///   - account: The account requesting the templates.
    ///   - options: Request configuration options (queue, headers, etc.).
    ///   - taskHandler: Optional callback to monitor the underlying URLSessionTask.
    /// - Returns: A tuple containing the account, list of templates (if any), raw response, and error information.
    func textGetListOfTemplatesAsync(account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        templates: [NKEditorTemplate]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textGetListOfTemplates(account: account,
                                   options: options,
                                   taskHandler: taskHandler) { account, templates, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    templates: templates,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Creates a new file using a specific editor, creator, and template.
    ///
    /// Parameters:
    /// - fileNamePath: The full destination path where the new file will be created.
    /// - editorId: The identifier of the editor to use (e.g., "richdocuments").
    /// - creatorId: The identifier of the creator (e.g., "document", "spreadsheet").
    /// - templateId: The identifier of the template to use for this file.
    /// - account: The account performing the operation.
    /// - options: Optional request configuration (headers, queue, version, etc.).
    /// - taskHandler: Callback to monitor the underlying URLSessionTask.
    /// - completion: Returns the account, the resulting file URL (if any), the raw response, and NKError.
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
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

    /// Asynchronously creates a new file from a template using the specified editor and creator.
    ///
    /// - Parameters:
    ///   - fileNamePath: Destination path where the new file will be saved.
    ///   - editorId: The editor's unique identifier (e.g., "richdocuments").
    ///   - creatorId: The creator's identifier (e.g., "document").
    ///   - templateId: The template to use for the new file.
    ///   - account: The Nextcloud account used for the operation.
    ///   - options: Optional request settings (e.g., headers, queue, etc.).
    ///   - taskHandler: Optional callback to observe the URLSessionTask.
    /// - Returns: A tuple containing the account, the resulting file URL, raw response data, and NKError.
    func textCreateFileAsync(fileNamePath: String,
                             editorId: String,
                             creatorId: String,
                             templateId: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        url: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textCreateFile(fileNamePath: fileNamePath,
                           editorId: editorId,
                           creatorId: creatorId,
                           templateId: templateId,
                           account: account,
                           options: options,
                           taskHandler: taskHandler) { account, url, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    url: url,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
}
