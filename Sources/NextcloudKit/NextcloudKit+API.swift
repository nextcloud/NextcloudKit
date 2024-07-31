//
//  NextcloudKit+API.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 07/05/2020.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
                     completion: @escaping (_ error: NKError) -> Void) {
        guard let url = serverUrl.asUrl else {
            return options.queue.async { completion(.urlError) }
        }

        AF.request(url, method: .head, parameters: nil, encoding: URLEncoding.default, headers: nil, interceptor: nil).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(error) }
            case .success:
                options.queue.async { completion(.success) }
            }
        }
    }

    // MARK: -

    func generalWithEndpoint(_ endpoint: String,
                             method: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: method.uppercased())
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, error) }
            case .success:
                options.queue.async { completion(account, response.data, .success) }
            }
        }
    }

    // MARK: -

    func getExternalSite(account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ externalFiles: [NKExternalSite], _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        var externalSites: [NKExternalSite] = []
        let endpoint = "ocs/v2.php/apps/external/api/v1"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, externalSites, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, externalSites, nil, error) }
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
                options.queue.async { completion(account, externalSites, jsonData, .success) }
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
                         completion: @escaping (ServerInfoResult) -> Void) {
        let endpoint = "status.php"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(ServerInfoResult.failure(.urlError)) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                return options.queue.async { completion(ServerInfoResult.failure(error)) }
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
                options.queue.async { completion(ServerInfoResult.success(serverInfo)) }
            }
        }
    }

    // MARK: -

    func downloadPreview(url: URL,
                         account: String,
                         etag: String? = nil,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {
        var headers = self.nkCommonInstance.getStandardHeaders(options: options)
        if var etag = etag {
            etag = "\"" + etag + "\""
            headers.update(name: "If-None-Match", value: etag)
        }

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, error) }
            case .success:
                if let data = response.data {
                    options.queue.async { completion(account, data, .success) }
                } else {
                    options.queue.async { completion(account, nil, .invalidData) }
                }
            }
        }
    }

    func downloadPreview(fileId: String,
                         widthPreview: Int = 512,
                         heightPreview: Int = 512,
                         etag: String? = nil,
                         crop: Int = 1,
                         cropMode: String = "cover",
                         forceIcon: Int = 0,
                         mimeFallback: Int = 0,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "index.php/core/preview?fileId=\(fileId)&x=\(widthPreview)&y=\(heightPreview)&a=\(crop)&mode=\(cropMode)&forceIcon=\(forceIcon)&mimeFallback=\(mimeFallback)"
        let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint)
        guard let urlRequest = url else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var headers = self.nkCommonInstance.getStandardHeaders(options: options)
        if var etag = etag {
            etag = "\"" + etag + "\""
            headers.update(name: "If-None-Match", value: etag)
        }

        sessionManager.request(urlRequest, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, error) }
            case .success:
                if let data = response.data {
                    options.queue.async { completion(account, data, .success) }
                } else {
                    options.queue.async { completion(account, nil, .invalidData) }
                }
            }
        }
    }

    func downloadPreview(fileId: String,
                         fileNamePreviewLocalPath: String,
                         fileNameIconLocalPath: String? = nil,
                         widthPreview: Int = 512,
                         heightPreview: Int = 512,
                         sizeIcon: Int = 512,
                         compressionQualityPreview: CGFloat = 0.5,
                         compressionQualityIcon: CGFloat = 0.5,
                         etag: String? = nil,
                         crop: Int = 1,
                         cropMode: String = "cover",
                         forceIcon: Int = 0,
                         mimeFallback: Int = 0,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ imagePreview: UIImage?, _ imageIcon: UIImage?, _ imageOriginal: UIImage?, _ etag: String?, _ error: NKError) -> Void) {
        let endpoint = "index.php/core/preview?fileId=\(fileId)&x=\(widthPreview)&y=\(heightPreview)&a=\(crop)&mode=\(cropMode)&forceIcon=\(forceIcon)&mimeFallback=\(mimeFallback)"

        downloadPreview(fileNamePreviewLocalPath: fileNamePreviewLocalPath, fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: sizeIcon, compressionQualityPreview: compressionQualityPreview, compressionQualityIcon: compressionQualityIcon, etag: etag, endpoint: endpoint, account: account, options: options) { task in
            taskHandler(task)
        } completion: { account, imagePreview, imageIcon, imageOriginal, etag, error in
            completion(account, imagePreview, imageIcon, imageOriginal,etag,error)
        }
    }

    func downloadTrashPreview(fileId: String,
                              fileNamePreviewLocalPath: String,
                              fileNameIconLocalPath: String,
                              widthPreview: Int = 512,
                              heightPreview: Int = 512,
                              sizeIcon: Int = 512,
                              compressionQualityPreview: CGFloat = 0.5,
                              compressionQualityIcon: CGFloat = 0.5,
                              crop: Int = 1,
                              cropMode: String = "cover",
                              forceIcon: Int = 0,
                              mimeFallback: Int = 0,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                              completion: @escaping (_ account: String, _ imagePreview: UIImage?, _ imageIcon: UIImage?, _ imageOriginal: UIImage?, _ etag: String?, _ error: NKError) -> Void) {
        let endpoint = "index.php/apps/files_trashbin/preview?fileId=\(fileId)&x=\(widthPreview)&y=\(heightPreview)&a=\(crop)&mode=\(cropMode)&forceIcon=\(forceIcon)&mimeFallback=\(mimeFallback)"

        downloadPreview(fileNamePreviewLocalPath: fileNamePreviewLocalPath, fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: sizeIcon, compressionQualityPreview: compressionQualityPreview, compressionQualityIcon: compressionQualityIcon, etag: nil, endpoint: endpoint, account: account, options: options) { task in
            taskHandler(task)
        } completion: { account, imagePreview, imageIcon, imageOriginal, etag, error in
            completion(account, imagePreview, imageIcon, imageOriginal,etag,error)
        }
    }

    private func downloadPreview(fileNamePreviewLocalPath: String,
                                 fileNameIconLocalPath: String? = nil,
                                 sizeIcon: Int = 0,
                                 compressionQualityPreview: CGFloat,
                                 compressionQualityIcon: CGFloat,
                                 etag: String? = nil,
                                 endpoint: String?,
                                 account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                 completion: @escaping (_ account: String, _ imagePreview: UIImage?, _ imageIcon: UIImage?, _ imageOriginal: UIImage?, _ etag: String?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        var url: URLConvertible?
        if let endpoint {
            url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint)
        }
        guard let urlRequest = url else {
            return options.queue.async { completion(account, nil, nil, nil, nil, .urlError) }
        }
        var headers = self.nkCommonInstance.getStandardHeaders(options: options)
        if var etag = etag {
            etag = "\"" + etag + "\""
            headers.update(name: "If-None-Match", value: etag)
        }

        sessionManager.request(urlRequest, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, nil, nil, error) }
            case .success:
                guard let data = response.data, let imageOriginal = UIImage(data: data) else {
                    return options.queue.async { completion(account, nil, nil, nil, nil, .invalidData) }
                }
                let etag = self.nkCommonInstance.findHeader("etag", allHeaderFields: response.response?.allHeaderFields)?.replacingOccurrences(of: "\"", with: "")
                var imagePreview, imageIcon: UIImage?
                do {
                    if let data = imageOriginal.jpegData(compressionQuality: compressionQualityPreview) {
                        try data.write(to: URL(fileURLWithPath: fileNamePreviewLocalPath), options: .atomic)
                        imagePreview = UIImage(data: data)
                    }
                    if let fileNameIconLocalPath, sizeIcon > 0 {
                        imageIcon = imageOriginal.resizeImage(size: CGSize(width: sizeIcon, height: sizeIcon))
                        if let data = imageIcon?.jpegData(compressionQuality: compressionQualityIcon) {
                            try data.write(to: URL(fileURLWithPath: fileNameIconLocalPath), options: .atomic)
                            imageIcon = UIImage(data: data)
                        }
                    }
                    options.queue.async { completion(account, imagePreview, imageIcon, imageOriginal, etag, .success) }
                } catch {
                    options.queue.async { completion(account, nil, nil, nil, nil, NKError(error: error)) }
                }
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
                        completion: @escaping (_ account: String, _ imageAvatar: UIImage?, _ imageOriginal: UIImage?, _ etag: String?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "index.php/avatar/\(user)/\(sizeImage)"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, nil, .urlError) }
        }
        var headers = self.nkCommonInstance.getStandardHeaders(options: options)
        if var etag = etag {
            etag = "\"" + etag + "\""
            headers.update(name: "If-None-Match", value: etag)
        }

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, nil, error) }
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
                            let screenScale = UIScreen.main.scale
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
                        options.queue.async { completion(account, imageAvatar, imageOriginal, etag, .success) }
                    } catch {
                        options.queue.async { completion(account, nil, nil, nil, NKError(error: error)) }
                    }
                } else {
                    options.queue.async { completion(account, nil, nil, nil, .invalidData) }
                }
            }
        }
    }

    func downloadContent(serverUrl: String,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {
        guard let url = serverUrl.asUrl else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, error) }
            case .success:
                if let data = response.data {
                    options.queue.async { completion(account, data, .success) }
                } else {
                    options.queue.async { completion(account, nil, .invalidData) }
                }
            }
        }
    }

    // MARK: -

    func getUserProfile(account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ userProfile: NKUserProfile?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "ocs/v2.php/cloud/user"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
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

                    options.queue.async { completion(account, userProfile, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func getCapabilities(account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "ocs/v1.php/cloud/capabilities"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, error) }
            case .success:
                if let jsonData = response.data {
                    options.queue.async { completion(account, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, .invalidData) }
                }
            }
        }
    }

    // MARK: -

    func getRemoteWipeStatus(serverUrl: String,
                             token: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ wipe: Bool, _ data: Data?, _ error: NKError) -> Void) {
        let endpoint = "index.php/core/wipe/check"
        let parameters: [String: Any] = ["token": token]
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/json")
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(account, false, nil, .urlError) }
        }

        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, false, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let wipe = json["wipe"].boolValue
                options.queue.async { completion(account, wipe, jsonData, .success) }
            }
        }
    }

    func setRemoteWipeCompletition(serverUrl: String,
                                   token: String,
                                   account: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                   completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let endpoint = "index.php/core/wipe/success"
        let parameters: [String: Any] = ["token": token]
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/json")
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return options.queue.async { completion(account, .urlError) }
        }

        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
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
                     completion: @escaping (_ account: String, _ activities: [NKActivity], _ activityFirstKnown: Int, _ activityLastGiven: Int, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
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

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, activities, activityFirstKnown, activityLastGiven, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, activities, activityFirstKnown, 0, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let ocsdata = json["ocs"]["data"]
                for (_, subJson): (String, JSON) in ocsdata {
                    let activity = NKActivity()

                    activity.app = subJson["app"].stringValue
                    activity.idActivity = subJson["activity_id"].intValue
                    if let datetime = subJson["datetime"].string {
                        if let date = self.nkCommonInstance.convertDate(datetime, format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
                            activity.date = date
                        }
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

                options.queue.async { completion(account, activities, activityFirstKnown, activityLastGiven, jsonData, .success) }
            }
        }
    }

    // MARK: -

    func getNotifications(account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ notifications: [NKNotifications]?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/notifications"
        var notifications: [NKNotifications] = []
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    let ocsdata = json["ocs"]["data"]
                    for (_, subJson): (String, JSON) in ocsdata {
                        let notification = NKNotifications()

                        if subJson["actions"].exists() {
                            do {
                                notification.actions = try subJson["actions"].rawData()
                            } catch {}
                        }
                        notification.app = subJson["app"].stringValue
                        if let datetime = subJson["datetime"].string {
                            if let date = self.nkCommonInstance.convertDate(datetime, format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
                                notification.date = date as Date
                            }
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
                    options.queue.async { completion(account, notifications, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
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
                         completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        var url: URLConvertible?
        if serverUrl == nil {
            let endpoint = "ocs/v2.php/apps/notifications/api/v2/notifications/\(idNotification)"
            url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint)
        } else {
            url = serverUrl?.asUrl
        }
        guard let urlRequest = url else {
            return options.queue.async { completion(account, .urlError) }
        }
        let method = HTTPMethod(rawValue: method)
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(urlRequest, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }

    // MARK: -

    func getDirectDownload(fileId: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ url: String?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "ocs/v2.php/apps/dav/api/v1/direct"
        let parameters: [String: Any] = [
            "fileId": fileId,
            "format": "json"
        ]
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let ocsdata = json["ocs"]["data"]
                let url = ocsdata["url"].string
                options.queue.async { completion(account, url, jsonData, .success) }
            }
        }
    }

    // MARK: -

    func sendClientDiagnosticsRemoteOperation(data: Data,
                                              account: String,
                                              options: NKRequestOptions = NKRequestOptions(),
                                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                              completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "ocs/v2.php/apps/security_guard/diagnostics"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/json")
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .put, headers: headers)
            urlRequest.httpBody = data
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }
}
