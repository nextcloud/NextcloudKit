// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Creates a folder on the Nextcloud server at the specified path.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The full URL string of the folder to create.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - ocId: Optional file ID assigned by the server for the new folder.
    ///     - date: Optional date from the server response headers.
    ///     - responseData: The raw Alamofire response data.
    ///     - error: The `NKError` result indicating success or failure.
    func createFolder(serverUrlFileName: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ ocId: String?, _ date: Date?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileName.encodedToUrl,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "MKCOL")
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, nil, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            var date: Date?
            let ocId = self.nkCommonInstance.findHeader("oc-fileid", allHeaderFields: response.response?.allHeaderFields)
            if let dateString = self.nkCommonInstance.findHeader("date", allHeaderFields: response.response?.allHeaderFields) {
                date = dateString.parsedDate(using: "EEE, dd MMM y HH:mm:ss zzz")
            }
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, ocId, date, response, result)
            }
        }
    }

    /// Asynchronously creates a folder on the Nextcloud server.
    ///
    /// - Parameters: Same as the sync version.
    /// - Returns: A tuple with account, optional ocId, optional date, responseData, and NKError.
    func createFolderAsync(serverUrlFileName: String,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        ocId: String?,
        date: Date?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            createFolder(serverUrlFileName: serverUrlFileName,
                         account: account,
                         options: options,
                         taskHandler: taskHandler) { account, ocId, date, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    ocId: ocId,
                    date: date,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Deletes a file or folder from the Nextcloud server at the specified URL.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The full URL string of the file or folder to delete.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - responseData: The raw Alamofire response data.
    ///     - error: The `NKError` result indicating success or failure.
    func deleteFileOrFolder(serverUrlFileName: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileName.encodedToUrl,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .delete, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously deletes a file or folder from the Nextcloud server.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The full URL string of the file or folder to delete.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the request.
    ///   - responseData: The raw Alamofire response data.
    ///   - error: The `NKError` result indicating success or failure.
    func deleteFileOrFolderAsync(serverUrlFileName: String,
                                 account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            deleteFileOrFolder(serverUrlFileName: serverUrlFileName,
                               account: account,
                               options: options,
                               taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Moves or renames a file or folder on the Nextcloud server.
    ///
    /// - Parameters:
    ///   - serverUrlFileNameSource: The full URL string of the source file or folder to move.
    ///   - serverUrlFileNameDestination: The full URL string of the destination path.
    ///   - overwrite: Whether to overwrite the destination if it exists.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - responseData: The raw Alamofire response data.
    ///     - error: The `NKError` result indicating success or failure.
    func moveFileOrFolder(serverUrlFileNameSource: String,
                          serverUrlFileNameDestination: String,
                          overwrite: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileNameSource.encodedToUrl,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "MOVE")
        headers.update(name: "Destination", value: serverUrlFileNameDestination.urlEncoded ?? "")
        if overwrite {
            headers.update(name: "Overwrite", value: "T")
        } else {
            headers.update(name: "Overwrite", value: "F")
        }
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously moves or renames a file or folder on the Nextcloud server.
    ///
    /// - Parameters:
    ///   - serverUrlFileNameSource: The full URL string of the source file or folder to move.
    ///   - serverUrlFileNameDestination: The full URL string of the destination path.
    ///   - overwrite: Whether to overwrite the destination if it exists.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the request.
    ///   - responseData: The raw Alamofire response data.
    ///   - error: The `NKError` result indicating success or failure.
    func moveFileOrFolderAsync(serverUrlFileNameSource: String,
                               serverUrlFileNameDestination: String,
                               overwrite: Bool,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource,
                             serverUrlFileNameDestination: serverUrlFileNameDestination,
                             overwrite: overwrite,
                             account: account,
                             options: options,
                             taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Copies a file or folder on the Nextcloud server from a source path to a destination path.
    ///
    /// - Parameters:
    ///   - serverUrlFileNameSource: The full URL string of the source file or folder to copy.
    ///   - serverUrlFileNameDestination: The full URL string of the destination path.
    ///   - overwrite: A Boolean indicating whether to overwrite the destination if it exists.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request configuration including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - responseData: The raw Alamofire response data.
    ///     - error: An `NKError` indicating success or failure.
    func copyFileOrFolder(serverUrlFileNameSource: String,
                          serverUrlFileNameDestination: String,
                          overwrite: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileNameSource.encodedToUrl,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "COPY")
        headers.update(name: "Destination", value: serverUrlFileNameDestination.urlEncoded ?? "")
        if overwrite {
            headers.update(name: "Overwrite", value: "T")
        } else {
            headers.update(name: "Overwrite", value: "F")
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously copies a file or folder on the Nextcloud server.
    ///
    /// - Parameters:
    ///   - serverUrlFileNameSource: The full URL string of the source file or folder.
    ///   - serverUrlFileNameDestination: The full URL string of the destination.
    ///   - overwrite: Indicates whether to overwrite existing destination.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Callback for the underlying `URLSessionTask`.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the request.
    ///   - responseData: The raw Alamofire response data.
    ///   - error: The resulting `NKError`.
    func copyFileOrFolderAsync(serverUrlFileNameSource: String,
                               serverUrlFileNameDestination: String,
                               overwrite: Bool,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource,
                             serverUrlFileNameDestination: serverUrlFileNameDestination,
                             overwrite: overwrite,
                             account: account,
                             options: options,
                             taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Reads the contents of a file or folder on the Nextcloud server.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The full URL string of the file or folder to read.
    ///   - depth: The depth level for folder traversal (e.g., "0", "1", "infinity").
    ///   - showHiddenFiles: Boolean flag indicating whether to show hidden files (default is true).
    ///   - includeHiddenFiles: An array of specific hidden filenames to include despite hidden status.
    ///   - requestBody: Optional raw data to send as the request body.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request configuration including headers, timeout, and queue.
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - files: An optional array of `NKFile` objects representing the contents.
    ///     - responseData: The raw Alamofire response data.
    ///     - error: An `NKError` indicating success or failure.
    func readFileOrFolder(serverUrlFileName: String,
                          depth: String,
                          showHiddenFiles: Bool = true,
                          includeHiddenFiles: [String] = [],
                          requestBody: Data? = nil,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var serverUrlFileName = serverUrlFileName
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = serverUrlFileName.encodedToUrl,
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        if depth == "0", serverUrlFileName.last == "/" {
            serverUrlFileName = String(serverUrlFileName.dropLast())
        } else if depth != "0", serverUrlFileName.last != "/" {
            serverUrlFileName = serverUrlFileName + "/"
        }
        let method = HTTPMethod(rawValue: "PROPFIND")
        headers.update(name: "Depth", value: depth)
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            if let requestBody {
                urlRequest.httpBody = requestBody
                urlRequest.timeoutInterval = options.timeout
            } else {
                urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodyFile(createProperties: options.createProperties, removeProperties: options.removeProperties).data(using: .utf8)
            }
        } catch {
            return options.queue.async { completion(account, nil, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success:
                if let xmlData = response.data {
                    Task {
                        let files = await NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataFile(xmlData: xmlData, nkSession: nkSession, rootFileName: self.nkCommonInstance.rootFileName, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles)
                        options.queue.async { completion(account, files, response, .success) }
                    }
                } else {
                    options.queue.async { completion(account, nil, response, .xmlError) }
                }
            }
        }
    }

    /// Asynchronously reads the contents of a file or folder.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The full URL string of the file or folder.
    ///   - depth: The depth level to traverse.
    ///   - showHiddenFiles: Whether to show hidden files.
    ///   - includeHiddenFiles: Specific hidden files to include.
    ///   - requestBody: Optional request body data.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Callback for the underlying URLSessionTask.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the request.
    ///   - files: Optional array of `NKFile` contents.
    ///   - responseData: The raw Alamofire response data.
    ///   - error: The resulting `NKError`.
    func readFileOrFolderAsync(serverUrlFileName: String,
                               depth: String,
                               showHiddenFiles: Bool = true,
                               includeHiddenFiles: [String] = [],
                               requestBody: Data? = nil,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        files: [NKFile]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            readFileOrFolder(serverUrlFileName: serverUrlFileName,
                             depth: depth,
                             showHiddenFiles: showHiddenFiles,
                             includeHiddenFiles: includeHiddenFiles,
                             requestBody: requestBody,
                             account: account,
                             options: options,
                             taskHandler: taskHandler) { account, files, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    files: files,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Retrieves a file object from the server using either a file ID or a direct link.
    ///
    /// - Parameters:
    ///   - fileId: Optional file identifier to fetch the file.
    ///   - link: Optional direct link to the file.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options (headers, queue, etc.).
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - file: Optional `NKFile` object representing the file.
    ///     - responseData: Raw Alamofire response data.
    ///     - error: An `NKError` indicating success or failure.
    func getFileFromFileId(fileId: String? = nil,
                           link: String? = nil,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ file: NKFile?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        var httpBody: Data?
        if let fileId = fileId {
            httpBody = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodySearchFileId(createProperties: options.createProperties, removeProperties: options.removeProperties), nkSession.userId, fileId).data(using: .utf8)
        } else if let link = link {
            let linkArray = link.components(separatedBy: "/")
            if let fileId = linkArray.last {
                httpBody = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodySearchFileId(createProperties: options.createProperties, removeProperties: options.removeProperties), nkSession.userId, fileId).data(using: .utf8)
            }
        }
        guard let httpBody = httpBody else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        search(serverUrl: nkSession.urlBase, httpBody: httpBody, showHiddenFiles: true, includeHiddenFiles: [], account: account, options: options) { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        } completion: { account, files, responseData, error in
            options.queue.async { completion(account, files?.first, responseData, error) }
        }
    }

    /// Asynchronously retrieves a file object using file ID or link.
    ///
    /// - Parameters:
    ///   - fileId: Optional file ID.
    ///   - link: Optional direct link.
    ///   - account: Nextcloud account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for URLSessionTask monitoring.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used.
    ///   - file: Optional `NKFile` object.
    ///   - responseData: Raw response data.
    ///   - error: Resulting `NKError`.
    func getFileFromFileIdAsync(fileId: String? = nil,
                                link: String? = nil,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        file: NKFile?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getFileFromFileId(fileId: fileId,
                              link: link,
                              account: account,
                              options: options,
                              taskHandler: taskHandler) { account, file, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    file: file,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Performs a search on the server with a given XML body request.
    ///
    /// - Parameters:
    ///   - serverUrl: The base URL of the server.
    ///   - requestBody: The XML request body as a string.
    ///   - showHiddenFiles: Whether to include hidden files in the search.
    ///   - includeHiddenFiles: An array of hidden file names to specifically include.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options (headers, queue, etc.).
    ///   - taskHandler: Callback triggered with the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - files: Optional array of `NKFile` results matching the search.
    ///     - responseData: Raw Alamofire response data.
    ///     - error: An `NKError` indicating success or failure.
    func searchBodyRequest(serverUrl: String,
                           requestBody: String,
                           showHiddenFiles: Bool,
                           includeHiddenFiles: [String] = [],
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        if let httpBody = requestBody.data(using: .utf8) {
            search(serverUrl: serverUrl, httpBody: httpBody, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles, account: account, options: options) { task in
                taskHandler(task)
            } completion: { account, files, responseData, error in
                options.queue.async { completion(account, files, responseData, error) }
            }
        }
    }

    /// Asynchronously performs a search on the server with an XML request body.
    ///
    /// - Parameters:
    ///   - serverUrl: The base URL of the server.
    ///   - requestBody: The XML request body string.
    ///   - showHiddenFiles: Flag to include hidden files.
    ///   - includeHiddenFiles: Array of hidden files to include.
    ///   - account: The Nextcloud account.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback to observe the underlying URLSessionTask.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used.
    ///   - files: Optional array of `NKFile` results.
    ///   - responseData: Raw response data.
    ///   - error: Resulting `NKError`.
    func searchBodyRequestAsync(serverUrl: String,
                                requestBody: String,
                                showHiddenFiles: Bool,
                                includeHiddenFiles: [String] = [],
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        files: [NKFile]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            searchBodyRequest(serverUrl: serverUrl,
                              requestBody: requestBody,
                              showHiddenFiles: showHiddenFiles,
                              includeHiddenFiles: includeHiddenFiles,
                              account: account,
                              options: options,
                              taskHandler: taskHandler) { account, files, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    files: files,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Performs a search on the server with a literal string query.
    ///
    /// - Parameters:
    ///   - serverUrl: The base URL of the server.
    ///   - depth: The depth of the search in the directory hierarchy.
    ///   - literal: The literal search string to query.
    ///   - showHiddenFiles: Whether to include hidden files in the search.
    ///   - includeHiddenFiles: Specific hidden files to include.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options (headers, queue, etc.).
    ///   - taskHandler: Callback for the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - files: Optional array of `NKFile` objects matching the search.
    ///     - responseData: Raw Alamofire response data.
    ///     - error: An `NKError` indicating success or failure.
    func searchLiteral(serverUrl: String,
                       depth: String,
                       literal: String,
                       showHiddenFiles: Bool,
                       includeHiddenFiles: [String] = [],
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let href = ("/files/" + nkSession.userId).urlEncoded  else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let requestBody = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodySearchFileName(createProperties: options.createProperties, removeProperties: options.removeProperties), href, depth, "%" + literal + "%")
        if let httpBody = requestBody.data(using: .utf8) {
            search(serverUrl: serverUrl, httpBody: httpBody, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles, account: account, options: options) { task in
                taskHandler(task)
            } completion: { account, files, responseData, error in
                options.queue.async { completion(account, files, responseData, error) }
            }
        }
    }

    /// Asynchronously performs a literal search on the server.
    ///
    /// - Parameters:
    ///   - serverUrl: The server base URL.
    ///   - depth: Search depth.
    ///   - literal: Literal query string.
    ///   - showHiddenFiles: Whether to include hidden files.
    ///   - includeHiddenFiles: Specific hidden files to include.
    ///   - account: Nextcloud account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for the underlying URLSessionTask.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the request.
    ///   - files: Optional array of NKFile results.
    ///   - responseData: Raw response data.
    ///   - error: Resulting NKError.
    func searchLiteralAsync(serverUrl: String,
                            depth: String,
                            literal: String,
                            showHiddenFiles: Bool,
                            includeHiddenFiles: [String] = [],
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        files: [NKFile]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            searchLiteral(serverUrl: serverUrl,
                          depth: depth,
                          literal: literal,
                          showHiddenFiles: showHiddenFiles,
                          includeHiddenFiles: includeHiddenFiles,
                          account: account,
                          options: options,
                          taskHandler: taskHandler) { account, files, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    files: files,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Searches media files within a specified date range on the server.
    ///
    /// - Parameters:
    ///   - path: The directory path to search within (default is empty string for root).
    ///   - lessDate: The upper bound date filter (files older than this).
    ///   - greaterDate: The lower bound date filter (files newer than this).
    ///   - elementDate: The file date attribute to filter on (e.g., "created", "modified").
    ///   - limit: Maximum number of files to return.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options (headers, queue, etc.).
    ///   - taskHandler: Callback for monitoring the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - files: Optional array of matching `NKFile` objects.
    ///     - responseData: Raw Alamofire response data.
    ///     - error: An `NKError` describing success or failure.
    func searchMedia(path: String = "",
                     lessDate: Any,
                     greaterDate: Any,
                     elementDate: String,
                     limit: Int,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let files: [NKFile] = []
        let elementDate = elementDate + "/"
        var greaterDateString: String?, lessDateString: String?
        let href = "/files/" + nkSession.userId + path
        if let lessDate = lessDate as? Date {
            lessDateString = lessDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        } else if let lessDate = lessDate as? Int {
            lessDateString = String(lessDate)
        }
        if let greaterDate = greaterDate as? Date {
            greaterDateString = greaterDate.formatted(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        } else if let greaterDate = greaterDate as? Int {
            greaterDateString = String(greaterDate)
        }
        guard let lessDateString, let greaterDateString else {
            return options.queue.async { completion(account, files, nil, .invalidDate) }
        }
        guard let httpBody = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodySearchMedia(createProperties: options.createProperties, removeProperties: options.removeProperties), href, elementDate, elementDate, lessDateString, elementDate, greaterDateString, String(limit)).data(using: .utf8) else {
            return options.queue.async { completion(account, files, nil, .invalidData) }
        }

        search(serverUrl: nkSession.urlBase, httpBody: httpBody, showHiddenFiles: false, includeHiddenFiles: [], account: account, options: options) { task in
            taskHandler(task)
        } completion: { account, files, responseData, error in
            options.queue.async { completion(account, files, responseData, error) }
        }
    }

    /// Asynchronously searches media files with date filters.
    ///
    /// - Parameters:
    ///   - path: Directory path to search.
    ///   - lessDate: Upper date bound filter.
    ///   - greaterDate: Lower date bound filter.
    ///   - elementDate: File date attribute to filter on.
    ///   - limit: Maximum number of results.
    ///   - account: Nextcloud account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Callback for URLSessionTask monitoring.
    ///
    /// - Returns: A tuple containing:
    ///   - account: Account used for the request.
    ///   - files: Optional array of `NKFile` matching results.
    ///   - responseData: Raw server response data.
    ///   - error: Resulting `NKError`.
    func searchMediaAsync(path: String = "",
                          lessDate: Any,
                          greaterDate: Any,
                          elementDate: String,
                          limit: Int,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        files: [NKFile]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            searchMedia(path: path,
                        lessDate: lessDate,
                        greaterDate: greaterDate,
                        elementDate: elementDate,
                        limit: limit,
                        account: account,
                        options: options,
                        taskHandler: taskHandler) { account, files, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    files: files,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Performs a private search request with a custom HTTP body on the server.
    ///
    /// - Parameters:
    ///   - serverUrl: The base URL of the Nextcloud server.
    ///   - httpBody: The raw HTTP request body data for the search.
    ///   - showHiddenFiles: Boolean indicating whether to include hidden files in the search.
    ///   - includeHiddenFiles: Specific hidden files to include despite general hidden files exclusion.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options (headers, queue, version, etc.).
    ///   - taskHandler: Callback to monitor the created `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the request.
    ///     - files: Optional array of `NKFile` matching the search.
    ///     - responseData: Raw response data from Alamofire.
    ///     - error: An `NKError` indicating success or failure.
    private func search(serverUrl: String,
                        httpBody: Data,
                        showHiddenFiles: Bool,
                        includeHiddenFiles: [String],
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        guard let url = (serverUrl + "/" + nkSession.dav).encodedToUrl else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "SEARCH")
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = httpBody
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success:
                if let xmlData = response.data {
                    Task {
                        let files = await NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataFile(xmlData: xmlData, nkSession: nkSession, rootFileName: self.nkCommonInstance.rootFileName, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles)
                        options.queue.async { completion(account, files, response, .success) }
                    }
                } else {
                    options.queue.async { completion(account, nil, response, .xmlError) }
                }
            }
        }
    }

    /// Asynchronously performs a search with a custom HTTP body.
    ///
    /// - Parameters:
    ///   - serverUrl: The base URL of the Nextcloud server.
    ///   - httpBody: The raw HTTP request body data for the search.
    ///   - showHiddenFiles: Boolean indicating whether to include hidden files in the search.
    ///   - includeHiddenFiles: Specific hidden files to include despite general hidden files exclusion.
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request options (headers, queue, version, etc.).
    ///   - taskHandler: Callback to monitor the created `URLSessionTask`.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the request.
    ///   - files: Optional array of `NKFile` results.
    ///   - responseData: Raw response data.
    ///   - error: Resulting `NKError`.
    private func searchAsync(serverUrl: String,
                             httpBody: Data,
                             showHiddenFiles: Bool,
                             includeHiddenFiles: [String],
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        files: [NKFile]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            search(serverUrl: serverUrl,
                   httpBody: httpBody,
                   showHiddenFiles: showHiddenFiles,
                   includeHiddenFiles: includeHiddenFiles,
                   account: account,
                   options: options,
                   taskHandler: taskHandler) { account, files, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    files: files,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Sets or removes a favorite flag on a specified file or folder on the Nextcloud server.
    ///
    /// - Parameters:
    ///   - fileName: The full path or URL-encoded name of the file or folder.
    ///   - favorite: A Boolean value indicating whether to set (`true`) or remove (`false`) the favorite status.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Optional request configuration (headers, queue, version, etc.).
    ///   - taskHandler: Callback for monitoring the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the operation.
    ///     - responseData: Raw Alamofire response data.
    ///     - error: An `NKError` indicating success or failure.
    func setFavorite(fileName: String,
                     favorite: Bool,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let serverUrlFileName = nkSession.urlBase + "/" + nkSession.dav + "/files/" + nkSession.userId + "/" + fileName
        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let body = NSString(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyFileSetFavorite as NSString, (favorite ? 1 : 0)) as String
            urlRequest.httpBody = body.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously sets or removes a favorite flag on a file or folder.
    ///
    /// - Parameters: Same as the synchronous version.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the operation.
    ///   - responseData: Raw response data from Alamofire.
    ///   - error: The resulting `NKError`.
    func setFavoriteAsync(fileName: String,
                          favorite: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            setFavorite(fileName: fileName,
                        favorite: favorite,
                        account: account,
                        options: options,
                        taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Lists all favorite files and folders for a user on the Nextcloud server.
    ///
    /// - Parameters:
    ///   - showHiddenFiles: Whether to include hidden files in the results.
    ///   - includeHiddenFiles: Specific hidden files to include even if `showHiddenFiles` is false.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Optional request configuration (headers, queue, version, etc.).
    ///   - taskHandler: Callback for monitoring the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the operation.
    ///     - files: An optional array of `NKFile` representing the favorite items.
    ///     - responseData: Raw Alamofire response data.
    ///     - error: An `NKError` indicating success or failure.
    func listingFavorites(showHiddenFiles: Bool,
                          includeHiddenFiles: [String] = [],
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let serverUrlFileName = nkSession.urlBase + "/" + nkSession.dav + "/files/" + nkSession.userId
        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "REPORT")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodyFileListingFavorites(createProperties: options.createProperties, removeProperties: options.removeProperties).data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success:
                if let xmlData = response.data {
                    Task {
                        let files = await NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataFile(xmlData: xmlData, nkSession: nkSession, rootFileName: self.nkCommonInstance.rootFileName, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles)
                        options.queue.async { completion(account, files, response, .success) }
                    }
                } else {
                    options.queue.async { completion(account, nil, response, .xmlError) }
                }
            }
        }
    }

    /// Asynchronously lists all favorite files and folders for a user.
    ///
    /// - Parameters: Same as the synchronous version.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the operation.
    ///   - files: An optional array of `NKFile` for the favorite items.
    ///   - responseData: Raw response data from Alamofire.
    ///   - error: The resulting `NKError`.
    func listingFavoritesAsync(showHiddenFiles: Bool,
                               includeHiddenFiles: [String] = [],
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        files: [NKFile]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            listingFavorites(showHiddenFiles: showHiddenFiles,
                             includeHiddenFiles: includeHiddenFiles,
                             account: account,
                             options: options,
                             taskHandler: taskHandler) { account, files, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    files: files,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Lists the contents of the trash bin for a user on the Nextcloud server.
    ///
    /// - Parameters:
    ///   - filename: Optional specific filename to filter the trash items.
    ///   - showHiddenFiles: Whether to include hidden files in the trash listing.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Optional request configuration (headers, queue, version, etc.).
    ///   - taskHandler: Callback for monitoring the underlying `URLSessionTask`.
    ///   - completion: Completion handler returning:
    ///     - account: The account used for the operation.
    ///     - items: An optional array of `NKTrash` objects representing trashed items.
    ///     - responseData: Raw Alamofire response data.
    ///     - error: An `NKError` indicating success or failure.
    func listingTrash(filename: String? = nil,
                      showHiddenFiles: Bool,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ items: [NKTrash]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        var serverUrlFileName = nkSession.urlBase + "/" + nkSession.dav + "/trashbin/" + nkSession.userId + "/trash/"
        if let filename {
            serverUrlFileName = serverUrlFileName + filename
        }
        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPFIND")
        headers.update(name: "Depth", value: "1")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyTrash.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success:
                if let xmlData = response.data {
                    Task {
                        let items = await NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataTrash(xmlData: xmlData, nkSession: nkSession, showHiddenFiles: showHiddenFiles)
                        options.queue.async { completion(account, items, response, .success) }
                    }
                } else {
                    options.queue.async { completion(account, nil, response, .xmlError) }
                }
            }
        }
    }

    /// Asynchronously lists the trash contents for a user.
    ///
    /// - Parameters: Same as the synchronous version.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the operation.
    ///   - items: An optional array of `NKTrash` representing trashed items.
    ///   - responseData: Raw response data from Alamofire.
    ///   - error: The resulting `NKError`.
    func listingTrashAsync(filename: String? = nil,
                           showHiddenFiles: Bool,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        items: [NKTrash]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            listingTrash(filename: filename,
                         showHiddenFiles: showHiddenFiles,
                         account: account,
                         options: options,
                         taskHandler: taskHandler) { account, items, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    items: items,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
}
