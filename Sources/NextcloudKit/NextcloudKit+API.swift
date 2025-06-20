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

    // MARK: -

    func generalWithEndpoint(_ endpoint: String,
                             account: String,
                             method: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    // MARK: -

    func getExternalSite(account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ externalSite: [NKExternalSite], _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var externalSites: [NKExternalSite] = []
        let endpoint = "ocs/v2.php/apps/external/api/v1"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    func getExternalSiteAsync(account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, externalSite: [NKExternalSite], responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation { continuation in
            getExternalSite(account: account,
                            options: options,
                            taskHandler: taskHandler) { account, externalSite, responseData, error in
                continuation.resume(returning: (account, externalSite, responseData, error))
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
        public let versionMajor: Int
        public let versionMinor: Int
        public let versionMicro: Int
        public let data: Data?
    }

    enum ServerInfoResult {
        case success(ServerInfo)
        case failure(NKError)
    }

    func getServerStatus(serverUrl: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ responseData: AFDataResponse<Data>?, ServerInfoResult) -> Void) {
        let endpoint = "status.php"
        guard let url = nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint, options: options) else {
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
                                            versionMajor: versionMajor,
                                            versionMinor: versionMinor,
                                            versionMicro: versionMicro,
                                            data: jsonData)
                options.queue.async { completion(response, ServerInfoResult.success(serverInfo)) }
            }
        }
    }

    func getServerStatusAsync(serverUrl: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (responseData: AFDataResponse<Data>?, result: ServerInfoResult) {
        await withUnsafeContinuation { continuation in
            getServerStatus(serverUrl: serverUrl,
                            options: options,
                            taskHandler: taskHandler) { responseData, result in
                continuation.resume(returning: (responseData, result))
            }
        }
    }

    // MARK: -

    func downloadPreview(url: URL,
                         account: String,
                         etag: String? = nil,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.getSession(account: account),
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

    func downloadPreviewAsync(url: URL,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions()) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.downloadPreview(url: url, account: account, options: options) { account, responseData, error in
                continuation.resume(returning: (account: account, responseData: responseData, error: error))
            }
        })
    }

    func downloadPreview(fileId: String,
                         width: Int = 1024,
                         height: Int = 1024,
                         etag: String? = nil,
                         crop: Int = 1,
                         cropMode: String = "cover",
                         forceIcon: Int = 0,
                         mimeFallback: Int = 0,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ width: Int, _ height: Int, _ etag: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/core/preview?fileId=\(fileId)&x=\(width)&y=\(height)&a=\(crop)&mode=\(cropMode)&forceIcon=\(forceIcon)&mimeFallback=\(mimeFallback)"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, width, height, nil, nil, .urlError) }
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
                options.queue.async { completion(account, width, height, nil, response, error) }
            case .success:
                let etag = self.nkCommonInstance.findHeader("etag", allHeaderFields: response.response?.allHeaderFields)?.replacingOccurrences(of: "\"", with: "")
                options.queue.async { completion(account, width, height, etag, response, .success) }
            }
        }
    }

    func downloadPreviewAsync(fileId: String,
                              etag: String? = nil,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions()) async -> (account: String, width: Int, height: Int, etag: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.downloadPreview(fileId: fileId, etag: etag, account: account, options: options) { account, width, height, etag, responseData, error in
                continuation.resume(returning: (account: account, width: width, height: height, etag: etag, responseData: responseData, error: error))
            }
        })
    }

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

        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    func downloadAvatar(user: String,
                        fileNameLocalPath: String,
                        sizeImage: Int,
                        avatarSizeRounded: Int = 0,
                        etag: String?,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ imageAvatar: UIImage?, _ imageOriginal: UIImage?, _ etag: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/avatar/\(user)/\(sizeImage)"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, nil, .urlError) }
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

    func downloadAvatarAsync(user: String,
                             fileNameLocalPath: String,
                             sizeImage: Int,
                             avatarSizeRounded: Int = 0,
                             etag: String?,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, imageAvatar: UIImage?, imageOriginal: UIImage?, etag: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation { continuation in
            downloadAvatar(user: user,
                           fileNameLocalPath: fileNameLocalPath,
                           sizeImage: sizeImage,
                           avatarSizeRounded: avatarSizeRounded,
                           etag: etag,
                           account: account,
                           options: options,
                           taskHandler: taskHandler) { account, imageAvatar, imageOriginal, etag, responseData, error in
                continuation.resume(returning: (account, imageAvatar, imageOriginal, etag, responseData, error))
            }
        }
    }

    func downloadContent(serverUrl: String,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrl.asUrl,
              let nkSession = nkCommonInstance.getSession(account: account),
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

    // MARK: -

    func getUserMetadata(account: String,
                         userId: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ userProfile: NKUserProfile?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/cloud/users/\(userId)"
        ///
        options.contentType = "application/json"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    func getUserMetadataAsync(account: String,
                              userId: String,
                              options: NKRequestOptions = NKRequestOptions()) async -> (account: String, userProfile: NKUserProfile?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            NextcloudKit.shared.getUserMetadata(account: account, userId: userId) { account, userProfile, responseData, error in
                continuation.resume(returning: (account: account, userProfile: userProfile, responseData: responseData, error: error))
            }
        })
    }

    func getUserProfile(account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ userProfile: NKUserProfile?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/cloud/user"
        ///
        options.contentType = "application/json"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    func getRemoteWipeStatus(serverUrl: String,
                             token: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ wipe: Bool, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/core/wipe/check"
        let parameters: [String: Any] = ["token": token]
        ///
        options.contentType = "application/json"
        ///
        guard let url = nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint, options: options) else {
            return options.queue.async { completion(account, false, nil, .urlError) }
        }
        var headers: HTTPHeaders?
        if let userAgent = options.customUserAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
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

    func setRemoteWipeCompletition(serverUrl: String,
                                   token: String,
                                   account: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                   completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/core/wipe/success"
        let parameters: [String: Any] = ["token": token]
        ///
        options.contentType = "application/json"
        ///
        guard let url = nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var headers: HTTPHeaders?
        if let userAgent = options.customUserAgent {
            headers = [HTTPHeader.userAgent(userAgent)]
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

    // MARK: -

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

        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    // MARK: -

    func getNotifications(account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ notifications: [NKNotifications]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/notifications"
        guard let nkSession = nkCommonInstance.getSession(account: account),
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

    func setNotification(serverUrl: String?,
                         idNotification: Int,
                         method: String,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var url: URLConvertible?
        if serverUrl == nil {
            let endpoint = "ocs/v2.php/apps/notifications/api/v2/notifications/\(idNotification)"
            url = self.nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options)
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

    // MARK: -

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
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    // MARK: -

    func sendClientDiagnosticsRemoteOperation(data: Data,
                                              account: String,
                                              options: NKRequestOptions = NKRequestOptions(),
                                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                              completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/security_guard/diagnostics"
        ///
        options.contentType = "application/json"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    func sendClientDiagnosticsRemoteOperationAsync(
        data: Data,
        account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation { continuation in
            sendClientDiagnosticsRemoteOperation(
                data: data,
                account: account,
                options: options,
                taskHandler: taskHandler
            ) { _, responseData, error in
                continuation.resume(returning: (responseData, error))
            }
        }
    }
}
