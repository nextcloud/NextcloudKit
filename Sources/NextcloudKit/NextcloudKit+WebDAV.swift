// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func createFolder(serverUrlFileName: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ ocId: String?, _ date: Date?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileName.encodedToUrl,
              let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
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

    func createFolderAsync(serverUrlFileName: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions()) async -> (account: String, ocId: String?, date: Date?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: account, options: options) { account, ocId, date, responseData, error in
                continuation.resume(returning: (account: account, ocId: ocId, date: date, responseData: responseData, error: error))
            }
        })
    }

    func deleteFileOrFolder(serverUrlFileName: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileName.encodedToUrl,
              let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
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

    func deleteFileOrFolderAsync(serverUrlFileName: String,
                                 account: String,
                                 options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func moveFileOrFolder(serverUrlFileNameSource: String,
                          serverUrlFileNameDestination: String,
                          overwrite: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileNameSource.encodedToUrl,
              let nkSession = nkCommonInstance.getSession(account: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
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

    func moveFileOrFolderAsync(serverUrlFileNameSource: String,
                               serverUrlFileNameDestination: String,
                               overwrite: Bool,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func copyFileOrFolder(serverUrlFileNameSource: String,
                          serverUrlFileNameDestination: String,
                          overwrite: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileNameSource.encodedToUrl,
              let nkSession = nkCommonInstance.getSession(account: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
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

    func copyFileOrFolderAsync(serverUrlFileNameSource: String,
                               serverUrlFileNameDestination: String,
                               overwrite: Bool,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func readFileOrFolder(serverUrlFileName: String,
                          depth: String,
                          showHiddenFiles: Bool = true,
                          includeHiddenFiles: [String] = [],
                          requestBody: Data? = nil,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var files: [NKFile] = []
        var serverUrlFileName = serverUrlFileName
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = serverUrlFileName.encodedToUrl,
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
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
            return options.queue.async { completion(account, files, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, files, response, error) }
            case .success:
                if let xmlData = response.data {
                    files = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataFile(xmlData: xmlData, nkSession: nkSession, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles)
                    options.queue.async { completion(account, files, response, .success) }
                } else {
                    options.queue.async { completion(account, files, response, .xmlError) }
                }
            }
        }
    }

    func readFileOrFolderAsync(serverUrlFileName: String,
                               depth: String,
                               showHiddenFiles: Bool = true,
                               requestBody: Data? = nil,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions()) async -> (account: String, files: [NKFile]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: depth, showHiddenFiles: showHiddenFiles, requestBody: requestBody, account: account, options: options) { account, files, responseData, error in
                continuation.resume(returning: (account: account, files: files, responseData: responseData, error: error))
            }
        })
    }

    func getFileFromFileId(fileId: String? = nil,
                           link: String? = nil,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ file: NKFile?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.getSession(account: account) else {
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

    func searchLiteral(serverUrl: String,
                       depth: String,
                       literal: String,
                       showHiddenFiles: Bool,
                       includeHiddenFiles: [String] = [],
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.getSession(account: account),
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

    func searchMedia(path: String = "",
                     lessDate: Any,
                     greaterDate: Any,
                     elementDate: String,
                     limit: Int,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.getSession(account: account) else {
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

    private func search(serverUrl: String,
                        httpBody: Data,
                        showHiddenFiles: Bool,
                        includeHiddenFiles: [String],
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        var files: [NKFile] = []
        guard let url = (serverUrl + "/" + nkSession.dav).encodedToUrl else {
            return options.queue.async { completion(account, files, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "SEARCH")
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = httpBody
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, files, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, files, response, error) }
            case .success:
                if let xmlData = response.data {
                    files = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataFile(xmlData: xmlData, nkSession: nkSession, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles)
                    options.queue.async { completion(account, files, response, .success) }
                } else {
                    options.queue.async { completion(account, files, response, .xmlError) }
                }
            }
        }
    }

    func setFavorite(fileName: String,
                     favorite: Bool,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
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

    func setFavoriteAsync(fileName: String,
                          favorite: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions()) async -> NKError {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite, account: account) { _, _, error in
                continuation.resume(returning: error)
            }
        })
    }

    func listingFavorites(showHiddenFiles: Bool,
                          includeHiddenFiles: [String] = [],
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ files: [NKFile]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let serverUrlFileName = nkSession.urlBase + "/" + nkSession.dav + "/files/" + nkSession.userId
        var files: [NKFile] = []
        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, files, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "REPORT")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodyFileListingFavorites(createProperties: options.createProperties, removeProperties: options.removeProperties).data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, files, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, files, response, error) }
            case .success:
                if let xmlData = response.data {
                    files = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataFile(xmlData: xmlData, nkSession: nkSession, showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles)
                    options.queue.async { completion(account, files, response, .success) }
                } else {
                    options.queue.async { completion(account, files, response, .xmlError) }
                }
            }
        }
    }

    func listingFavoritesAsync(showHiddenFiles: Bool,
                               includeHiddenFiles: [String] = [],
                               account: String,
                               options: NKRequestOptions = NKRequestOptions()) async -> (account: String, files: [NKFile]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.listingFavorites(showHiddenFiles: showHiddenFiles, includeHiddenFiles: includeHiddenFiles, account: account, options: options) { account, files, data, error in
                continuation.resume(returning: (account, files, data, error))
            }
        })
    }

    func listingTrash(filename: String? = nil,
                      showHiddenFiles: Bool,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ items: [NKTrash]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        var serverUrlFileName = nkSession.urlBase + "/" + nkSession.dav + "/trashbin/" + nkSession.userId + "/trash/"
        if let filename {
            serverUrlFileName = serverUrlFileName + filename
        }
        var items: [NKTrash] = []
        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, items, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPFIND")
        headers.update(name: "Depth", value: "1")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyTrash.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, items, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, items, response, error) }
            case .success:
                if let xmlData = response.data {
                    items = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataTrash(xmlData: xmlData, nkSession: nkSession, showHiddenFiles: showHiddenFiles)
                    options.queue.async { completion(account, items, response, .success) }
                } else {
                    options.queue.async { completion(account, items, response, .xmlError) }
                }
            }
        }
    }

    func listingTrashAsync(filename: String? = nil,
                           showHiddenFiles: Bool,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, items: [NKTrash]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation { continuation in
            listingTrash(filename: filename,
                         showHiddenFiles: showHiddenFiles,
                         account: account,
                         options: options,
                         taskHandler: taskHandler) { account, items, responseData, error in
                continuation.resume(returning: (account, items, responseData, error))
            }
        }
    }
}
