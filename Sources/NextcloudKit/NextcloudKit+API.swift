// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

#if os(macOS)
import Foundation
import AppKit
#else
import UIKit
#endif
import Alamofire
import SwiftyJSON

public class NKNotifications: NSObject {
    public var actions: Data?
    public var app = ""
    public var date = Date()
    public var icon: String?
    public var idNotification: Int = 0
    public var link = ""
    public var message = ""
    public var messageRich = ""
    public var messageRichParameters: Data?
    public var objectId = ""
    public var objectType = ""
    public var subject = ""
    public var subjectRich = ""
    public var subjectRichParameters: Data?
    public var user = ""
}

public extension NextcloudKit {
    /// Checks if the specified server URL is reachable and returns the raw HTTP response.
    /// Used to verify the availability and responsiveness of a Nextcloud server.
    ///
    /// Parameters:
    /// - serverUrl: Full URL of the Nextcloud server to check.
    /// - options: Optional request options (e.g. custom headers, queue).
    /// - taskHandler: Closure to access the URLSessionTask (default is no-op).
    /// - completion: Completion handler with the raw HTTP response and any NKError.
    func checkServer(serverUrl: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrl.asUrl else {
            return options.queue.async { completion(nil, .urlError) }
        }

        unauthorizedSession.request(url, method: .head, encoding: URLEncoding.default).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)
            options.queue.async {
                completion(response, result)
            }
        }
    }

    /// Asynchronously checks the specified server URL and returns the HTTP response and error.
    /// - Parameters:
    ///   - serverUrl: The URL of the server to check.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the session task.
    /// - Returns: A tuple containing the raw response and NKError, with named values.
    func checkServerAsync(serverUrl: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            checkServer(serverUrl: serverUrl,
                        options: options,
                        taskHandler: taskHandler) { responseData, error in
                continuation.resume(returning: (
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    // MARK: -

    /// Executes a generic HTTP request using the given relative endpoint path and HTTP method.
    /// Commonly used for flexible OCS or WebDAV API calls without dedicated wrappers.
    ///
    /// Parameters:
    /// - endpoint: The relative API path (e.g. "ocs/v2.php/apps/...") to be appended to the base server URL.
    /// - account: The Nextcloud account initiating the request.
    /// - method: The HTTP method as a string ("GET", "POST", "DELETE", etc).
    /// - options: Optional request options such as custom headers, versioning, queue.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, raw response, and any NKError.
    func generalWithEndpoint(_ endpoint: String,
                             account: String,
                             method: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: method.uppercased())

        nkSession.sessionData.request(url, method: method, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)
            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Asynchronously performs a generic request using the specified endpoint and method.
    /// - Parameters:
    ///   - endpoint: Relative path to the server API.
    ///   - account: The account initiating the request.
    ///   - method: HTTP method string.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Closure to access the URLSessionTask.
    /// - Returns: A tuple with named values: account, raw response, and error.
    func generalWithEndpointAsync(_ endpoint: String,
                                   account: String,
                                   method: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            generalWithEndpoint(endpoint,
                                account: account,
                                method: method,
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

    // MARK: -

    /// Retrieves the list of external sites configured in the Nextcloud instance.
    /// These are typically links to external services or resources displayed in the web UI.
    ///
    /// Parameters:
    /// - account: The Nextcloud account making the request.
    /// - options: Optional request options for custom headers, versioning, queue, etc.
    /// - taskHandler: Closure to access the URLSessionTask (default is no-op).
    /// - completion: Completion handler returning the account, list of external sites, response, and any NKError.
    func getExternalSite(account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ externalSite: [NKExternalSite], _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var externalSites: [NKExternalSite] = []
        let endpoint = "ocs/v2.php/apps/external/api/v1"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, externalSites, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, externalSites, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let ocsdata = json["ocs"]["data"]
                for (_, subJson): (String, JSON) in ocsdata {
                    let extrernalSite = NKExternalSite()
                    extrernalSite.icon = subJson["icon"].stringValue
                    extrernalSite.idExternalSite = subJson["id"].intValue
                    extrernalSite.lang = subJson["lang"].stringValue
                    extrernalSite.name = subJson["name"].stringValue
                    extrernalSite.type = subJson["type"].stringValue
                    extrernalSite.url = subJson["url"].stringValue
                    externalSites.append(extrernalSite)
                }
                options.queue.async { completion(account, externalSites, response, .success) }
            }
        }
    }

    /// Asynchronously retrieves the list of external sites for the specified account.
    /// - Parameters:
    ///   - account: The Nextcloud account making the request.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Closure to access the URLSessionTask.
    /// - Returns: A tuple containing account, external sites array, raw response, and error.
    func getExternalSiteAsync(account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        externalSite: [NKExternalSite],
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getExternalSite(account: account,
                            options: options,
                            taskHandler: taskHandler) { account, externalSite, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    externalSite: externalSite,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    // MARK: - getServerStatus

    struct ServerInfo {
        public let installed: Bool
        public let maintenance: Bool
        public let needsDbUpgrade: Bool
        public let extendedSupport: Bool
        public let productName: String
        public let version: String
        public let instanceid: String
        public let edition: String
        public let versionMajor: Int
        public let versionMinor: Int
        public let versionMicro: Int
        public let data: Data?
    }

    enum ServerInfoResult {
        case success(ServerInfo)
        case failure(NKError)
    }

    /// Retrieves the status information of a Nextcloud server.
    ///
    /// Parameters:
    /// - serverUrl: The base URL of the Nextcloud server (e.g., https://cloud.example.com).
    /// - options: Optional request configuration (e.g., headers, queue, etc.).
    /// - taskHandler: Callback for the underlying URLSessionTask.
    /// - completion: Returns the raw response and a `ServerInfoResult` containing server status information or an error.
    func getServerStatus(serverUrl: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ responseData: AFDataResponse<Data>?, ServerInfoResult) -> Void) {
        let endpoint = "status.php"
        guard let url = nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(nil, ServerInfoResult.failure(.urlError)) }
        }
        var headers: HTTPHeaders?
        if let userAgent = options.customUserAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
        }

        unauthorizedSession.request(url, method: .get, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                return options.queue.async { completion(response, ServerInfoResult.failure(error)) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                var versionMajor = 0, versionMinor = 0, versionMicro = 0
                let version = json["version"].stringValue
                let arrayVersion = version.components(separatedBy: ".")
                if arrayVersion.count == 1 {
                    versionMajor = Int(arrayVersion[0]) ?? 0
                } else if arrayVersion.count == 2 {
                    versionMajor = Int(arrayVersion[0]) ?? 0
                    versionMinor = Int(arrayVersion[1]) ?? 0
                } else if arrayVersion.count >= 3 {
                    versionMajor = Int(arrayVersion[0]) ?? 0
                    versionMinor = Int(arrayVersion[1]) ?? 0
                    versionMicro = Int(arrayVersion[2]) ?? 0
                }
                let serverInfo = ServerInfo(installed: json["installed"].boolValue,
                                            maintenance: json["maintenance"].boolValue,
                                            needsDbUpgrade: json["needsDbUpgrade"].boolValue,
                                            extendedSupport: json["extendedSupport"].boolValue,
                                            productName: json["productname"].stringValue,
                                            version: json["versionstring"].stringValue,
                                            instanceid: json["instanceid"].stringValue,
                                            edition: json["edition"].stringValue,
                                            versionMajor: versionMajor,
                                            versionMinor: versionMinor,
                                            versionMicro: versionMicro,
                                            data: jsonData)
                options.queue.async { completion(response, ServerInfoResult.success(serverInfo)) }
            }
        }
    }

    /// Asynchronously retrieves the status information of a Nextcloud server.
    /// - Parameters:
    ///   - serverUrl: The server's base URL (e.g., https://cloud.example.com).
    ///   - options: Optional request configuration (e.g., version, queue, headers).
    ///   - taskHandler: Optional callback to monitor the underlying URLSessionTask.
    /// - Returns: A tuple containing the AFDataResponse and the ServerInfoResult.
    func getServerStatusAsync(serverUrl: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        responseData: AFDataResponse<Data>?,
        result: ServerInfoResult
    ) {
        await withCheckedContinuation { continuation in
            getServerStatus(serverUrl: serverUrl,
                            options: options,
                            taskHandler: taskHandler) { responseData, result in
                continuation.resume(returning: (
                    responseData: responseData,
                    result: result
                ))
            }
        }
    }

    // MARK: -

    /// Downloads a file preview (thumbnail) from the specified URL for a given Nextcloud account.
    ///
    /// Parameters:
    /// - url: The full URL of the preview image to download.
    /// - account: The Nextcloud account used for the request.
    /// - etag: Optional entity tag used for cache validation.
    /// - options: Optional request configuration (e.g., headers, queue, version).
    /// - taskHandler: Callback for the underlying `URLSessionTask`.
    /// - completion: Returns the account, raw response data, and an `NKError` representing the result of the operation.
    func downloadPreview(url: URL,
                         account: String,
                         etag: String? = nil,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        if var etag = etag {
            etag = "\"" + etag + "\""
            headers.update(name: "If-None-Match", value: etag)
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, response, error) }
            case .success:
                options.queue.async { completion(account, response, .success) }
            }
        }
    }

    /// Asynchronously downloads a preview image (e.g., thumbnail) from the provided URL.
    /// - Parameters:
    ///   - url: The full URL of the preview image.
    ///   - account: The Nextcloud account making the request.
    ///   - etag: Optional ETag used to validate cache.
    ///   - options: Additional request options including version, headers, and queues.
    ///   - taskHandler: Optional handler for monitoring the URLSessionTask.
    /// - Returns: A tuple containing the account identifier, response data, and an `NKError` object.
    func downloadPreviewAsync(url: URL,
                              account: String,
                              etag: String? = nil,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            downloadPreview(url: url,
                            account: account,
                            etag: etag,
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

    /// Downloads a preview (thumbnail) of a file with specified dimensions and parameters.
    ///
    /// Parameters:
    /// - fileId: The identifier of the file to generate a preview for.
    /// - width: The desired width of the preview image (default is 1024).
    /// - height: The desired height of the preview image (default is 1024).
    /// - etag: Optional entity tag used for caching validation. ()
    /// - crop: Indicates whether the image should be cropped (1 = true, default).
    /// - cropMode: The cropping mode (default is "cover").
    /// - forceIcon: If set to 1, forces icon generation (default is 0).
    /// - mimeFallback: If set to 1, fallback to MIME-type icon if preview is unavailable (default is 0).
    /// - account: The Nextcloud account performing the operation.
    /// - options: Optional request configuration (headers, versioning, etc.).
    /// - taskHandler: Callback for the `URLSessionTask`.
    /// - completion: Returns the account, final width and height used, etag, response data, and any error encountered.
    func downloadPreview(fileId: String,
                         width: Int = 1024,
                         height: Int = 1024,
                         etag: String,
                         etagResource: String? = nil,
                         crop: Int = 1,
                         cropMode: String = "cover",
                         forceIcon: Int = 0,
                         mimeFallback: Int = 0,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ width: Int, _ height: Int, _ etag: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        //
        // Adding the etag as a parameter in the endpoint URL is used to prevent URLCache from being used in case the image has been overwritten.
        //
        let endpoint = "index.php/core/preview?fileId=\(fileId)&x=\(width)&y=\(height)&a=\(crop)&mode=\(cropMode)&forceIcon=\(forceIcon)&mimeFallback=\(mimeFallback)&etag=\(etag)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, width, height, nil, nil, .urlError) }
        }

        if var etagResource = etagResource {
            etagResource = "\"" + etagResource + "\""
            headers.update(name: "If-None-Match", value: etagResource)
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, width, height, nil, response, error) }
            case .success:
                let etag = self.nkCommonInstance.findHeader("etag", allHeaderFields: response.response?.allHeaderFields)?.replacingOccurrences(of: "\"", with: "")
                options.queue.async { completion(account, width, height, etag, response, .success) }
            }
        }
    }

    /// Asynchronously downloads a preview by file ID with specified dimensions and parameters.
    /// - Parameters:
    ///   - fileId: The unique identifier of the file.
    ///   - width: Desired preview width (default: 1024).
    ///   - height: Desired preview height (default: 1024).
    ///   - etag: Optional ETag for cache validation.
    ///   - crop: Crop flag (default: 1).
    ///   - cropMode: Crop mode (default: "cover").
    ///   - forceIcon: Force icon flag (default: 0).
    ///   - mimeFallback: MIME fallback flag (default: 0).
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to handle the URLSessionTask.
    /// - Returns: A tuple containing account, dimensions, ETag, response and error.
    func downloadPreviewAsync(fileId: String,
                              width: Int = 1024,
                              height: Int = 1024,
                              etag: String,
                              etagResource: String? = nil,
                              crop: Int = 1,
                              cropMode: String = "cover",
                              forceIcon: Int = 0,
                              mimeFallback: Int = 0,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        width: Int,
        height: Int,
        etag: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            downloadPreview(fileId: fileId,
                            width: width,
                            height: height,
                            etag: etag,
                            etagResource: etagResource,
                            crop: crop,
                            cropMode: cropMode,
                            forceIcon: forceIcon,
                            mimeFallback: mimeFallback,
                            account: account,
                            options: options,
                            taskHandler: taskHandler) { account, w, h, tag, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    width: w,
                    height: h,
                    etag: tag,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Downloads a preview (thumbnail) for a file located in the trashbin.
    ///
    /// Parameters:
    /// - fileId: The identifier of the trashed file.
    /// - width: Desired width of the preview image (default is 512).
    /// - height: Desired height of the preview image (default is 512).
    /// - crop: Indicates whether the image should be cropped (1 = true, default).
    /// - cropMode: The cropping mode (e.g., "cover").
    /// - forceIcon: Forces use of the filetype icon instead of generating a preview (0 = false, default).
    /// - mimeFallback: Uses MIME-type fallback if preview is unavailable (0 = false, default).
    /// - account: The Nextcloud account making the request.
    /// - options: Request customization options (headers, queue, version, etc.).
    /// - taskHandler: Callback to inspect the underlying URLSessionTask.
    /// - completion: Returns the account, final width/height, preview response data, and NKError.
    func downloadTrashPreview(fileId: String,
                              width: Int = 512,
                              height: Int = 512,
                              crop: Int = 1,
                              cropMode: String = "cover",
                              forceIcon: Int = 0,
                              mimeFallback: Int = 0,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                              completion: @escaping (_ account: String, _ width: Int, _ height: Int, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/apps/files_trashbin/preview?fileId=\(fileId)&x=\(width)&y=\(height)&a=\(crop)&mode=\(cropMode)&forceIcon=\(forceIcon)&mimeFallback=\(mimeFallback)"

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, width, height, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, width, height, response, error) }
            case .success:
                options.queue.async { completion(account, width, height, response, .success) }
            }
        }
    }

    /// Asynchronously downloads a preview of a trashed file using specified rendering options.
    /// - Parameters:
    ///   - fileId: The identifier of the trashed file.
    ///   - width: Desired width of the preview image.
    ///   - height: Desired height of the preview image.
    ///   - crop: Whether to crop the image (1 = true, 0 = false).
    ///   - cropMode: Cropping mode to apply (e.g., "cover").
    ///   - forceIcon: Whether to return an icon instead of a generated preview.
    ///   - mimeFallback: Whether to fallback to MIME-type icon if no preview is available.
    ///   - account: Account making the preview request.
    ///   - options: Optional request configuration (queue, headers, etc.).
    ///   - taskHandler: Handler to observe the URLSessionTask.
    /// - Returns: A tuple with account, final width and height used, responseData, and NKError.
    func downloadTrashPreviewAsync(fileId: String,
                                   width: Int = 512,
                                   height: Int = 512,
                                   crop: Int = 1,
                                   cropMode: String = "cover",
                                   forceIcon: Int = 0,
                                   mimeFallback: Int = 0,
                                   account: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        width: Int,
        height: Int,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            downloadTrashPreview(fileId: fileId,
                                 width: width,
                                 height: height,
                                 crop: crop,
                                 cropMode: cropMode,
                                 forceIcon: forceIcon,
                                 mimeFallback: mimeFallback,
                                 account: account,
                                 options: options,
                                 taskHandler: taskHandler) { account, resolvedWidth, resolvedHeight, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    width: resolvedWidth,
                    height: resolvedHeight,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Downloads a user's avatar image from the server and optionally stores it locally.
    ///
    /// Parameters:
    /// - user: The user identifier for whom the avatar is requested.
    /// - fileNameLocalPath: The local file path where the avatar image will be saved.
    /// - sizeImage: The size of the avatar to request (in pixels).
    /// - avatarSizeRounded: If greater than 0, the avatar will be rounded to this size (in pixels).
    /// - etag: Optional ETag string to validate the cache.
    /// - account: The Nextcloud account performing the operation.
    /// - options: Optional request options (queue, headers, etc.).
    /// - taskHandler: Callback for the underlying URLSessionTask.
    /// - completion: Returns the account, avatar image, original image, ETag, response data, and NKError.
    func downloadAvatar(user: String,
                        fileNameLocalPath: String,
                        sizeImage: Int,
                        avatarSizeRounded: Int = 0,
                        etagResource: String?,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ imageAvatar: UIImage?, _ imageOriginal: UIImage?, _ etag: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/avatar/\(user)/\(sizeImage)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, nil, .urlError) }
        }

        if var etagResource = etagResource {
            etagResource = "\"" + etagResource + "\""
            headers.update(name: "If-None-Match", value: etagResource)
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, nil, response, error) }
            case .success:
                if let data = response.data {
                    let imageOriginal = UIImage(data: data)
                    let etag = self.nkCommonInstance.findHeader("etag", allHeaderFields: response.response?.allHeaderFields)?.replacingOccurrences(of: "\"", with: "")
                    var imageAvatar: UIImage?
                    do {
                        let url = URL(fileURLWithPath: fileNameLocalPath)
                        if avatarSizeRounded > 0, let image = UIImage(data: data) {
                            imageAvatar = image

                            #if os(macOS)
                            let rect = CGRect(x: 0, y: 0, width: avatarSizeRounded, height: avatarSizeRounded)
                            var transform = CGAffineTransform.identity

                            let path = withUnsafePointer(to: &transform) { (pointer: UnsafePointer<CGAffineTransform>) in
                                CGPath(roundedRect: rect, cornerWidth: rect.width, cornerHeight: rect.height, transform: pointer)
                            }
                            let maskLayer = CAShapeLayer()
                            maskLayer.path = path

                            let layerToMask = CALayer()
                            layerToMask.contents = imageAvatar?.cgImage!
                            layerToMask.mask = maskLayer

                            let contextRef = CGContext(data: nil, width: Int(rect.width), height: Int(rect.height), bitsPerComponent: image.cgImage!.bitsPerComponent, bytesPerRow: image.cgImage!.bytesPerRow, space: image.cgImage!.colorSpace!, bitmapInfo: image.cgImage!.bitmapInfo.rawValue)
                            layerToMask.render(in: contextRef!)
                            #else

                            #if os(iOS)
                            var screenScale = 1.0
                            if #available(iOS 13.0, *) {
                                let semaphore = DispatchSemaphore(value: 0)
                                Task {
                                    screenScale = await UIScreen.main.scale
                                    semaphore.signal()
                                }
                                semaphore.wait()
                            } else {
                                #if swift(<6.0)
                                screenScale = UIScreen.main.scale
                                #endif
                            }
                            #else
                            let screenScale = 1.0
                            #endif
                            let rect = CGRect(x: 0, y: 0, width: avatarSizeRounded / Int(screenScale), height: avatarSizeRounded / Int(screenScale))
                            UIGraphicsBeginImageContextWithOptions(rect.size, false, screenScale)
                            UIBezierPath(roundedRect: rect, cornerRadius: rect.size.height).addClip()
                            imageAvatar?.draw(in: rect)
                            imageAvatar = UIGraphicsGetImageFromCurrentImageContext() ?? image
                            UIGraphicsEndImageContext()
                            #endif

                            if let pngData = imageAvatar?.pngData() {
                                try pngData.write(to: url)
                            } else {
                                try data.write(to: url)
                            }
                        } else {
                            try data.write(to: url)
                        }
                        options.queue.async { completion(account, imageAvatar, imageOriginal, etag, response, .success) }
                    } catch {
                        options.queue.async { completion(account, nil, nil, nil, response, NKError(error: error)) }
                    }
                } else {
                    options.queue.async { completion(account, nil, nil, nil, response, .invalidData) }
                }
            }
        }
    }

    /// Asynchronously downloads an avatar image for the specified user.
    /// - Parameters:
    ///   - user: The username associated with the avatar.
    ///   - fileNameLocalPath: Path on disk to save the avatar.
    ///   - sizeImage: Desired size (in pixels) of the avatar image.
    ///   - avatarSizeRounded: Optional rounding for avatar (e.g., 128px).
    ///   - etag: Optional ETag for cache validation.
    ///   - account: The Nextcloud account to perform the download.
    ///   - options: Request configuration (queue, headers, etc.).
    ///   - taskHandler: Optional observer for the download task.
    /// - Returns: A tuple with account, final avatar image, original image, resulting ETag, response and NKError.
    func downloadAvatarAsync(user: String,
                             fileNameLocalPath: String,
                             sizeImage: Int,
                             avatarSizeRounded: Int = 0,
                             etagResource: String?,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        imageAvatar: UIImage?,
        imageOriginal: UIImage?,
        etag: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            downloadAvatar(user: user,
                           fileNameLocalPath: fileNameLocalPath,
                           sizeImage: sizeImage,
                           avatarSizeRounded: avatarSizeRounded,
                           etagResource: etagResource,
                           account: account,
                           options: options,
                           taskHandler: taskHandler) { account, imageAvatar, imageOriginal, etag, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    imageAvatar: imageAvatar,
                    imageOriginal: imageOriginal,
                    etag: etag,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Downloads generic raw content from a given server URL using the specified account.
    ///
    /// Parameters:
    /// - serverUrl: The full URL string of the content to be downloaded.
    /// - account: The Nextcloud account to use for the request.
    /// - options: Optional configuration including headers, queue, and version.
    /// - taskHandler: Optional callback for monitoring the URLSessionTask.
    /// - completion: Returns the account, response data, and NKError representing the outcome.
    func downloadContent(serverUrl: String,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrl.asUrl,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, response, error) }
            case .success:
                options.queue.async { completion(account, response, .success) }
            }
        }
    }

    /// Asynchronously downloads raw content from a specified URL.
    /// - Parameters:
    ///   - serverUrl: The direct URL of the content to download.
    ///   - account: The Nextcloud account used to authenticate the request.
    ///   - options: Request customization such as headers, queue, etc.
    ///   - taskHandler: Optional monitoring for the URLSession task.
    /// - Returns: A tuple containing the account, response data, and resulting NKError.
    func downloadContentAsync(serverUrl: String,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            downloadContent(serverUrl: serverUrl,
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

    // MARK: -

    /// Retrieves user profile metadata for a specific user in the Nextcloud instance.
    ///
    /// Parameters:
    /// - account: The account used to perform the request.
    /// - userId: The user identifier whose metadata is being retrieved.
    /// - options: Additional request configuration (e.g., headers, API version, execution queue).
    /// - taskHandler: Optional callback invoked with the underlying URLSessionTask.
    /// - completion: Returns the account, parsed user profile (`NKUserProfile`), response metadata, and any `NKError` encountered.
    func getUserMetadata(account: String,
                         userId: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ userProfile: NKUserProfile?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/cloud/users/\(userId)"

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionDataNoCache.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)

                if let userProfile = self.getUserProfile(json: json) {
                    options.queue.async { completion(account, userProfile, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves the metadata for a specific user profile.
    /// - Parameters:
    ///   - account: The Nextcloud account making the request.
    ///   - userId: The ID of the user whose metadata is being requested.
    ///   - options: Optional request configuration (headers, version, etc.).
    ///   - taskHandler: Optional handler for observing the URLSessionTask.
    /// - Returns: A tuple with the account, user profile, response data, and resulting error.
    func getUserMetadataAsync(account: String,
                              userId: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        userProfile: NKUserProfile?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getUserMetadata(account: account,
                            userId: userId,
                            options: options,
                            taskHandler: taskHandler) { account, userProfile, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    userProfile: userProfile,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Fetches the metadata of the currently authenticated user.
    ///
    /// Parameters:
    /// - account: The Nextcloud account performing the request.
    /// - options: Additional request configuration (e.g., custom headers, API version, execution queue).
    /// - taskHandler: Optional callback invoked with the underlying URLSessionTask.
    /// - completion: Returns the account, parsed user profile (`NKUserProfile`), response metadata, and any `NKError` encountered.
    func getUserProfile(account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ userProfile: NKUserProfile?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/cloud/user"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionDataNoCache.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)

                if let userProfile = self.getUserProfile(json: json) {
                    options.queue.async { completion(account, userProfile, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously fetches the profile metadata of the currently logged-in user.
    /// - Parameters:
    ///   - account: The Nextcloud account making the request.
    ///   - options: Optional request configuration (e.g. headers, version, etc.).
    ///   - taskHandler: Optional handler for observing the URLSessionTask.
    /// - Returns: A tuple containing the account, user profile object, full response data, and any NKError.
    func getUserProfileAsync(account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        userProfile: NKUserProfile?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getUserProfile(account: account,
                           options: options,
                           taskHandler: taskHandler) { account, userProfile, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    userProfile: userProfile,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    private func getUserProfile(json: JSON) -> NKUserProfile? {
        let ocs = json["ocs"]
        let data = ocs["data"]

        if json["ocs"]["meta"]["statuscode"].int == 200 {
            let userProfile = NKUserProfile()

            userProfile.address = data["address"].stringValue
            userProfile.backend = data["backend"].stringValue
            userProfile.backendCapabilitiesSetDisplayName = data["backendCapabilities"]["setDisplayName"].boolValue
            userProfile.backendCapabilitiesSetPassword = data["backendCapabilities"]["setPassword"].boolValue
            userProfile.displayName = data["display-name"].stringValue
            userProfile.email = data["email"].stringValue
            userProfile.enabled = data["enabled"].boolValue
            if let groups = data["groups"].array {
                for group in groups {
                    userProfile.groups.append(group.stringValue)
                }
            }
            userProfile.userId = data["id"].stringValue
            userProfile.language = data["language"].stringValue
            userProfile.lastLogin = data["lastLogin"].int64Value
            userProfile.locale = data["locale"].stringValue
            userProfile.organisation = data["organisation"].stringValue
            userProfile.phone = data["phone"].stringValue
            userProfile.quotaFree = data["quota"]["free"].int64Value
            userProfile.quota = data["quota"]["quota"].int64Value
            userProfile.quotaRelative = data["quota"]["relative"].doubleValue
            userProfile.quotaTotal = data["quota"]["total"].int64Value
            userProfile.quotaUsed = data["quota"]["used"].int64Value
            userProfile.storageLocation = data["storageLocation"].stringValue
            if let subadmins = data["subadmin"].array {
                for subadmin in subadmins {
                    userProfile.subadmin.append(subadmin.stringValue)
                }
            }
            userProfile.twitter = data["twitter"].stringValue
            userProfile.website = data["website"].stringValue

            return userProfile
        }

        return nil
    }
    // MARK: -

    /// Checks the remote wipe status for a specific account and token.
    ///
    /// Parameters:
    /// - serverUrl: The base server URL to perform the request.
    /// - token: The authentication or wipe token to validate.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional configuration for the request (e.g., headers, version, queue).
    /// - taskHandler: Optional callback to observe the underlying URLSessionTask.
    /// - completion: Returns the account, wipe status (true if a wipe is required), raw response data, and NKError if any.
    func getRemoteWipeStatus(serverUrl: String,
                             token: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ wipe: Bool, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/core/wipe/check"
        let parameters: [String: Any] = ["token": token]

        guard let url = nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(account, false, nil, .urlError) }
        }
        var headers: HTTPHeaders = [
            "Content-Type": "application/json",
        ]
        if let userAgent = options.customUserAgent {
            headers.add(.userAgent(userAgent))
        }

        unauthorizedSession.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, false, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let wipe = json["wipe"].boolValue
                options.queue.async { completion(account, wipe, response, .success) }
            }
        }
    }

    /// Asynchronously checks the remote wipe status for the given account and token.
    /// - Parameters:
    ///   - serverUrl: Base server URL used for the API request.
    ///   - token: Token used to query remote wipe status.
    ///   - account: Nextcloud account identifier.
    ///   - options: Request options such as headers, version, and dispatch queue.
    ///   - taskHandler: Callback for observing the URLSessionTask, if needed.
    /// - Returns: A tuple with the account, wipe status flag, response data, and NKError.
    func getRemoteWipeStatusAsync(serverUrl: String,
                                  token: String,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        wipe: Bool,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getRemoteWipeStatus(serverUrl: serverUrl,
                                token: token,
                                account: account,
                                options: options,
                                taskHandler: taskHandler) { account, wipe, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    wipe: wipe,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Notifies the server that the remote wipe operation has been completed.
    ///
    /// Parameters:
    /// - serverUrl: The base server URL used to send the wipe completion notification.
    /// - token: The remote wipe token associated with the account.
    /// - account: The Nextcloud account that performed the wipe.
    /// - options: Optional configuration for request (headers, queue, version, etc.).
    /// - taskHandler: Callback for the underlying URLSessionTask if monitoring is needed.
    /// - completion: Returns the account, raw response data, and NKError.
    func setRemoteWipeCompletition(serverUrl: String,
                                   token: String,
                                   account: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                   completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/core/wipe/success"
        let parameters: [String: Any] = ["token": token]
        guard let url = nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var headers: HTTPHeaders = [
            "Content-Type": "application/json",
        ]
        if let userAgent = options.customUserAgent {
            headers.add(.userAgent(userAgent))
        }

        unauthorizedSession.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, response, error) }
            case .success:
                options.queue.async { completion(account, response, .success) }
            }
        }
    }

    /// Asynchronously notifies the server that remote wipe has been completed for the given account and token.
    /// - Parameters:
    ///   - serverUrl: The base URL of the Nextcloud server.
    ///   - token: Remote wipe token associated with the account.
    ///   - account: Identifier of the Nextcloud account.
    ///   - options: Configuration object for headers, versioning, and dispatching.
    ///   - taskHandler: Optional observer for the created URLSessionTask.
    /// - Returns: A tuple with account, raw response data, and NKError.
    func setRemoteWipeCompletitionAsync(serverUrl: String,
                                        token: String,
                                        account: String,
                                        options: NKRequestOptions = NKRequestOptions(),
                                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            setRemoteWipeCompletition(serverUrl: serverUrl,
                                      token: token,
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

    // MARK: -

    /// Retrieves a list of activities for the current account.
    ///
    /// Parameters:
    /// - since: The timestamp (as Unix epoch) to fetch activities after.
    /// - limit: The maximum number of activities to retrieve.
    /// - objectId: Optional object ID to filter activities (e.g., file ID).
    /// - objectType: Optional object type to filter (e.g., "files").
    /// - previews: Whether to include preview data for activities.
    /// - account: The Nextcloud account requesting the activity feed.
    /// - options: Optional request configuration (headers, queue, version, etc.).
    /// - taskHandler: Callback for the underlying URLSessionTask.
    /// - completion: Returns the account, array of NKActivity objects, the timestamp of the first known activity, last returned activity, raw response, and NKError.
    func getActivity(since: Int,
                     limit: Int,
                     objectId: String?,
                     objectType: String?,
                     previews: Bool,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ activities: [NKActivity], _ activityFirstKnown: Int, _ activityLastGiven: Int, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var activities: [NKActivity] = []
        var activityFirstKnown = 0
        var activityLastGiven = 0
        var endpoint = "ocs/v2.php/apps/activity/api/v2/activity/"
        var parameters: [String: Any] = [
            "format": "json",
            "since": String(since),
            "limit": String(limit)
        ]

        if let objectId = objectId, let objectType = objectType {
            endpoint += "filter"
            parameters["object_id"] = objectId
            parameters["object_type"] = objectType
        } else {
            endpoint += "all"
        }

        if previews {
            parameters["previews"] = "true"
        }

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, activities, activityFirstKnown, activityLastGiven, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, activities, activityFirstKnown, 0, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let ocsdata = json["ocs"]["data"]
                for (_, subJson): (String, JSON) in ocsdata {
                    let activity = NKActivity()

                    activity.app = subJson["app"].stringValue
                    activity.idActivity = subJson["activity_id"].intValue
                    if let datetime = subJson["datetime"].string,
                       let date = datetime.parsedDate(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
                        activity.date = date
                    }
                    activity.icon = subJson["icon"].stringValue
                    activity.link = subJson["link"].stringValue
                    activity.message = subJson["message"].stringValue
                    if subJson["message_rich"].exists() {
                        do {
                            activity.messageRich = try subJson["message_rich"].rawData()
                        } catch {}
                    }
                    activity.objectId = subJson["object_id"].intValue
                    activity.objectName = subJson["object_name"].stringValue
                    activity.objectType = subJson["object_type"].stringValue
                    if subJson["previews"].exists() {
                        do {
                            activity.previews = try subJson["previews"].rawData()
                        } catch {}
                    }
                    activity.subject = subJson["subject"].stringValue
                    if subJson["subject_rich"].exists() {
                        do {
                            activity.subjectRich = try subJson["subject_rich"].rawData()
                        } catch {}
                    }
                    activity.type = subJson["type"].stringValue
                    activity.user = subJson["user"].stringValue

                    activities.append(activity)
                }

                let firstKnown: String = self.nkCommonInstance.findHeader("X-Activity-First-Known", allHeaderFields: response.response?.allHeaderFields) ?? "0"
                let lastGiven: String = self.nkCommonInstance.findHeader("X-Activity-Last-Given", allHeaderFields: response.response?.allHeaderFields) ?? "0"

                if let iFirstKnown = Int(firstKnown) { activityFirstKnown = iFirstKnown }
                if let ilastGiven = Int(lastGiven) { activityLastGiven = ilastGiven }

                options.queue.async { completion(account, activities, activityFirstKnown, activityLastGiven, response, .success) }
            }
        }
    }

    /// Asynchronously fetches the list of activities from the server.
    ///
    /// - Parameters:
    ///   - since: Epoch timestamp for filtering activities (only newer ones will be returned).
    ///   - limit: Maximum number of activities to retrieve.
    ///   - objectId: Optional object ID to filter (e.g., file or folder ID).
    ///   - objectType: Optional object type (e.g., "files").
    ///   - previews: Whether to include thumbnails/previews for the activities.
    ///   - account: The Nextcloud account to use for authentication.
    ///   - options: Request customization including queue and headers.
    ///   - taskHandler: Optional callback for URLSession task monitoring.
    /// - Returns: A tuple containing account, activities array, first known activity timestamp, last given activity timestamp, full response, and error.
    func getActivityAsync(since: Int,
                          limit: Int,
                          objectId: String?,
                          objectType: String?,
                          previews: Bool,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        activities: [NKActivity],
        activityFirstKnown: Int,
        activityLastGiven: Int,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getActivity(since: since,
                        limit: limit,
                        objectId: objectId,
                        objectType: objectType,
                        previews: previews,
                        account: account,
                        options: options,
                        taskHandler: taskHandler) { account, activities, firstKnown, lastGiven, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    activities: activities,
                    activityFirstKnown: firstKnown,
                    activityLastGiven: lastGiven,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    // MARK: -

    /// Retrieves all notifications associated with the current account.
    ///
    /// Parameters:
    /// - account: The Nextcloud account from which to retrieve notifications.
    /// - options: Optional request configuration (headers, queue, version, etc.).
    /// - taskHandler: Callback for the underlying URLSessionTask.
    /// - completion: Returns the account, list of NKNotifications, raw response data, and NKError.
    func getNotifications(account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ notifications: [NKNotifications]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/notifications"
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
                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    let ocsdata = json["ocs"]["data"]
                    var notifications: [NKNotifications] = []
                    for (_, subJson): (String, JSON) in ocsdata {
                        let notification = NKNotifications()

                        if subJson["actions"].exists() {
                            do {
                                notification.actions = try subJson["actions"].rawData()
                            } catch {}
                        }
                        notification.app = subJson["app"].stringValue
                        if let datetime = subJson["datetime"].string,
                           let date = datetime.parsedDate(using: "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
                            notification.date = date
                        }
                        notification.icon = subJson["icon"].string
                        notification.idNotification = subJson["notification_id"].intValue
                        notification.link = subJson["link"].stringValue
                        notification.message = subJson["message"].stringValue
                        notification.messageRich = subJson["messageRich"].stringValue
                        if subJson["messageRichParameters"].exists() {
                            do {
                                notification.messageRichParameters = try subJson["messageRichParameters"].rawData()
                            } catch {}
                        }
                        notification.objectId = subJson["object_id"].stringValue
                        notification.objectType = subJson["object_type"].stringValue
                        notification.subject = subJson["subject"].stringValue
                        notification.subjectRich = subJson["subjectRich"].stringValue
                        if subJson["subjectRichParameters"].exists() {
                            do {
                                notification.subjectRichParameters = try subJson["subjectRichParameters"].rawData()
                            } catch {}
                        }
                        notification.user = subJson["user"].stringValue
                        notifications.append(notification)
                    }
                    options.queue.async { completion(account, notifications, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously fetches notifications for the given account.
    ///
    /// - Parameters:
    ///   - account: The Nextcloud account used to authenticate the request.
    ///   - options: Request configuration including queue and headers.
    ///   - taskHandler: Optional callback to monitor the URLSessionTask.
    /// - Returns: A tuple containing the account, notifications array (optional), response data (optional), and the resulting NKError.
    func getNotificationsAsync(account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        notifications: [NKNotifications]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getNotifications(account: account,
                             options: options,
                             taskHandler: taskHandler) { account, notifications, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    notifications: notifications,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Performs an action on a specific notification by ID (e.g., mark as read or delete).
    ///
    /// Parameters:
    /// - serverUrl: Optional custom server URL override. If nil, the default account URL is used.
    /// - idNotification: The ID of the notification to act upon.
    /// - method: The HTTP method to use for the action (e.g., "DELETE" or "POST").
    /// - account: The account associated with the notification.
    /// - options: Optional request configuration (headers, queue, version, etc.).
    /// - taskHandler: Callback for the underlying URLSessionTask.
    /// - completion: Returns the account, raw response data, and NKError result.
    func setNotification(serverUrl: String?,
                         idNotification: Int,
                         method: String,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var url: URLConvertible?
        if serverUrl == nil {
            let endpoint = "ocs/v2.php/apps/notifications/api/v2/notifications/\(idNotification)"
            url = self.nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint)
        } else {
            url = serverUrl?.asUrl
        }
        guard let urlRequest = url else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: method)

        nkSession.sessionData.request(urlRequest, method: method, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, response, error) }
            case .success:
                options.queue.async { completion(account, response, .success) }
            }
        }
    }

    /// Asynchronously sets or deletes a notification by its ID.
    ///
    /// - Parameters:
    ///   - serverUrl: Optional server URL override for the request.
    ///   - idNotification: The unique identifier of the notification to process.
    ///   - method: HTTP method to execute ("POST", "DELETE", etc.).
    ///   - account: The account context for the operation.
    ///   - options: Request options including queue, headers, etc.
    ///   - taskHandler: Optional callback to monitor the task.
    /// - Returns: A tuple containing the account, response data, and NKError.
    func setNotificationAsync(serverUrl: String?,
                              idNotification: Int,
                              method: String,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            setNotification(serverUrl: serverUrl,
                            idNotification: idNotification,
                            method: method,
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

    // MARK: -

    // Fetches a direct download URL for a given file ID.
    //
    // Parameters:
    // - fileId: The unique identifier of the file to download.
    // - account: The account used to perform the request.
    // - options: Optional request configuration (headers, queue, version, etc.).
    // - taskHandler: Callback triggered with the URLSessionTask created.
    // - completion: Returns the account, the direct download URL (if available), raw response data, and NKError result.
    func getDirectDownload(fileId: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ url: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/dav/api/v1/direct"
        let parameters: [String: Any] = [
            "fileId": fileId,
            "format": "json"
        ]
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

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
                let ocsdata = json["ocs"]["data"]
                let url = ocsdata["url"].string
                options.queue.async { completion(account, url, response, .success) }
            }
        }
    }

    /// Asynchronously retrieves the direct download link for a specified file.
    ///
    /// - Parameters:
    ///   - fileId: The file identifier for which to get the direct download URL.
    ///   - account: The account to use for the request.
    ///   - options: Optional request settings (e.g., headers, versioning).
    ///   - taskHandler: Callback to observe the URLSessionTask.
    /// - Returns: A tuple containing the account, the direct download URL, the raw response, and NKError.
    func getDirectDownloadAsync(fileId: String,
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
            getDirectDownload(fileId: fileId,
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

    // MARK: -

    // Sends client diagnostics data to the remote server.
    //
    // Parameters:
    // - data: The raw diagnostic payload to be sent.
    // - account: The account used for the request.
    // - options: Optional request configuration (e.g., headers, queue, version).
    // - taskHandler: Callback triggered with the underlying URLSessionTask.
    // - completion: Returns the account, raw response data, and NKError result.
    func sendClientDiagnosticsRemoteOperation(data: Data,
                                              account: String,
                                              options: NKRequestOptions = NKRequestOptions(),
                                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                              completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/security_guard/diagnostics"

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .put, headers: headers)
            urlRequest.httpBody = data
        } catch {
            return options.queue.async { completion(account, nil, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, response, error) }
            case .success:
                options.queue.async { completion(account, response, .success) }
            }
        }
    }

    /// Asynchronously sends diagnostic data to the server.
    ///
    /// - Parameters:
    ///   - data: Raw diagnostic information to upload.
    ///   - account: The account associated with the request.
    ///   - options: Optional request configuration parameters.
    ///   - taskHandler: Callback for tracking the associated URLSessionTask.
    /// - Returns: A tuple containing the account, the response data, and the NKError result.
    func sendClientDiagnosticsRemoteOperationAsync(data: Data,
                                                   account: String,
                                                   options: NKRequestOptions = NKRequestOptions(),
                                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            sendClientDiagnosticsRemoteOperation(data: data,
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
}
