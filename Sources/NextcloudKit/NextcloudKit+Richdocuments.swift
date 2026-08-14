// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Requests a URL for editing or viewing a file via Richdocuments (Nextcloud Office/Collabora).
    ///
    /// Parameters:
    /// - fileId: The unique identifier of the file for which the document URL is requested.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional configuration such as custom headers, queue, or API version.
    /// - taskHandler: Callback invoked when the underlying URLSessionTask is created.
    /// - completion: Completion handler returning the account, document URL (if available),
    ///            the raw HTTP response, and an NKError object.
    func createRichdocumentsEditorURL(fileId: String,
                                      account: String,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                      completion: @escaping (_ account: String, _  url: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/richdocuments/api/v1/document"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters: [String: Any] = ["fileId": fileId]

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    let url = json["ocs"]["data"]["url"].stringValue
                    options.queue.async { completion(account, url, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves the URL for opening a file in Richdocuments (Nextcloud Office/Collabora).
    ///
    /// - Parameters:
    ///   - fileId: The identifier of the target file.
    ///   - account: The Nextcloud account used for the operation.
    ///   - options: Request configuration (headers, queue, version, etc.).
    ///   - taskHandler: Optional handler to observe the URLSessionTask.
    /// - Returns: A tuple containing the account, the richdocument URL (if any), the raw response data, and any NKError.
    func createRichdocumentsEditorURLAsync(fileId: String,
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
            createRichdocumentsEditorURL(fileId: fileId,
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

    /// Retrieves the list of Richdocuments templates of a given type (e.g., "document", "spreadsheet").
    ///
    /// Parameters:
    /// - templateType: The type of template to retrieve (e.g., "document", "presentation").
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional configuration (headers, queue, API version, etc.).
    /// - taskHandler: Callback invoked when the underlying URLSessionTask is created.
    /// - completion: Completion handler returning the account, array of templates, response data, and NKError.
    func getRichdocumentsTemplates(templateType: String,
                                   account: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                   completion: @escaping (_ account: String, _ templates: [NKRichdocumentsTemplate]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/richdocuments/api/v1/templates/\(templateType)"
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
            case .success(let jsonData):
                let json = JSON(jsonData)
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
                    options.queue.async { completion(account, templates, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously fetches Richdocuments templates filtered by type.
    ///
    /// - Parameters:
    ///   - templateType: The type of template to retrieve (e.g., "document").
    ///   - account: The Nextcloud account for which templates are requested.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Optional handler to observe the `URLSessionTask`.
    /// - Returns: A tuple containing the account, array of templates, raw response data, and any NKError.
    func getRichdocumentsTemplatesAsync(templateType: String,
                                        account: String,
                                        options: NKRequestOptions = NKRequestOptions(),
                                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        templates: [NKRichdocumentsTemplate]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getRichdocumentsTemplates(templateType: templateType,
                                      account: account,
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

    /// Creates a new Richdocuments file using a specific template.
    ///
    /// Parameters:
    /// - filePath: The target path where the new document should be created.
    /// - templateId: The ID of the Richdocuments template to use.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional request configuration (headers, queue, API version, etc.).
    /// - taskHandler: Callback invoked when the underlying URLSessionTask is created.
    /// - completion: Completion handler returning the account, emporary asset URL, raw response, and NKError.
    func createRichdocumentsFileFromTemplate(filePath: String,
                                             templateId: String,
                                             account: String,
                                             options: NKRequestOptions = NKRequestOptions(),
                                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                             completion: @escaping (_ account: String, _  url: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/richdocuments/api/v1/templates/new"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters: [String: Any] = ["path": filePath, "template": templateId]

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    let url = json["ocs"]["data"]["url"].stringValue
                    options.queue.async { completion(account, url, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously creates a new Richdocuments file from a given template.
    ///
    /// - Parameters:
    ///   - filePath: Destination path for the new document.
    ///   - templateId: Template ID used to generate the new file.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Optional request parameters.
    ///   - taskHandler: Optional monitoring of the underlying task.
    /// - Returns: A tuple with account, resulting URL (if successful), raw response, and error result.
    func createRichdocumentsFileFromTemplateAsync(filePath: String,
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
            createRichdocumentsFileFromTemplate(filePath: filePath,
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

    /// Creates a temporary Richdocuments asset URL for an existing file.
    ///
    /// Parameters:
    /// - filePath: Path of the existing file to expose temporarily to Collabora.
    /// - account: The Nextcloud account initiating the creation.
    /// - options: Optional configuration for the request (e.g. headers, queue, API version).
    /// - taskHandler: Callback invoked when the underlying URLSessionTask is created.
    /// - completion: Completion handler returning account, emporary asset URL, raw response data, and NKError.
    func createRichdocumentsAssetURL(filePath: String,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                     completion: @escaping (_ account: String, _  url: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/apps/richdocuments/assets"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters: [String: Any] = ["path": filePath]

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let url = json["url"].string
                options.queue.async { completion(account, url, response, .success) }
            }
        }
    }

    /// Asynchronously creates a temporary Richdocuments asset URL for an existing file.
    ///
    /// - Parameters:
    ///   - filePath: Path of the existing file to expose temporarily to Collabora.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Optional request customization.
    ///   - taskHandler: Optional monitoring of the underlying task.
    /// - Returns: A tuple with account, resulting URL, raw response, and error.
    func createRichdocumentsAssetURLAsync(filePath: String,
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
            createRichdocumentsAssetURL(filePath: filePath,
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
