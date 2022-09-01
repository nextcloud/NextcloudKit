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

extension NextcloudKit {
    
    //MARK: -
    
    @objc public func checkServer(serverUrl: String, queue: DispatchQueue = .main, completionHandler: @escaping (_ error: NKError) -> Void) {
        
        guard let url = serverUrl.asUrl else {
            return queue.async { completionHandler(.urlError) }
        }
        
        let method = HTTPMethod(rawValue: "HEAD")
                
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: nil, interceptor: nil).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(error) }
            case .success( _):
                queue.async { completionHandler(.success) }
            }
        }
    }
    
    //MARK: -

    @objc public func generalWithEndpoint(_ endpoint:String, method: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ responseData: Data?, _ error: NKError) -> Void) {
                
        let account = NKCommon.shared.account

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: method.uppercased())
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success( _):
                queue.async { completionHandler(account, response.data, .success) }
            }
        }
    }
    
    //MARK: -
    
    @objc public func getExternalSite(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ externalFiles: [NKExternalSite], _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account
        var externalSites: [NKExternalSite] = []

        let endpoint = "ocs/v2.php/apps/external/api/v1?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, externalSites, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, externalSites, error) }
            case .success(let json):
                let json = JSON(json)
                let ocsdata = json["ocs"]["data"]
                for (_, subJson):(String, JSON) in ocsdata {
                    let extrernalSite = NKExternalSite()
                    
                    extrernalSite.icon = subJson["icon"].stringValue
                    extrernalSite.idExternalSite = subJson["id"].intValue
                    extrernalSite.lang = subJson["lang"].stringValue
                    extrernalSite.name = subJson["name"].stringValue
                    extrernalSite.type = subJson["type"].stringValue
                    extrernalSite.url = subJson["url"].stringValue
                    
                    externalSites.append(extrernalSite)
                }
                queue.async { completionHandler(account, externalSites, .success) }
            }
        }
    }
    
    @objc public func getServerStatus(serverUrl: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ serverProductName: String?, _ serverVersion: String? , _ versionMajor: Int, _ versionMinor: Int, _ versionMicro: Int, _ extendedSupport: Bool, _ error: NKError) -> Void) {
                
        let endpoint = "status.php"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return queue.async { completionHandler(nil, nil, 0, 0, 0, false, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(nil, nil, 0, 0, 0, false, error) }
            case .success(let json):
                let json = JSON(json)
                var versionMajor = 0, versionMinor = 0, versionMicro = 0
                
                let serverProductName = json["productname"].stringValue.lowercased()
                let serverVersion = json["version"].stringValue
                let serverVersionString = json["versionstring"].stringValue
                let extendedSupport = json["extendedSupport"].boolValue
                    
                let arrayVersion = serverVersion.components(separatedBy: ".")
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
                
                queue.async { completionHandler(serverProductName, serverVersionString, versionMajor, versionMinor, versionMicro, extendedSupport, .success) }
            }
        }
    }
    
    //MARK: -
    
    @objc public func getPreview(url: URL, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {

        let account = NKCommon.shared.account

        let method = HTTPMethod(rawValue: "GET")

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
                
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success( _):
                if let data = response.data {
                    queue.async { completionHandler(account, data, .success) }
                } else {
                    queue.async { completionHandler(account, nil, .invalidData) }
                }
            }
        }
    }
    
    @objc public func downloadPreview(fileNamePathOrFileId: String, fileNamePreviewLocalPath: String, widthPreview: Int, heightPreview: Int, fileNameIconLocalPath: String? = nil, sizeIcon: Int = 0, etag: String?, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, endpointTrashbin: Bool = false, useInternalEndpoint: Bool = true, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ imagePreview: UIImage?, _ imageIcon: UIImage?, _ imageOriginal: UIImage?, _ etag: String?, _ error: NKError) -> Void) {
               
        let account = NKCommon.shared.account
        var endpoint = ""
        var url: URLConvertible?

        if useInternalEndpoint {
            
            if endpointTrashbin {
                endpoint = "index.php/apps/files_trashbin/preview?fileId=" + fileNamePathOrFileId + "&x=\(widthPreview)&y=\(heightPreview)"
            } else {
                guard let fileNamePath = fileNamePathOrFileId.urlEncoded else {
                    queue.async { completionHandler(account, nil, nil, nil, nil, .urlError) }
                    return
                }
                endpoint = "index.php/core/preview.png?file=" + fileNamePath + "&x=\(widthPreview)&y=\(heightPreview)&a=1&mode=cover"
            }
                
            url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint)
            
        } else {
            
            url = fileNamePathOrFileId.asUrl
        }
        
        guard let urlRequest = url else {
            return queue.async { completionHandler(account, nil, nil, nil, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        var headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        if var etag = etag {
            etag = "\"" + etag + "\""
            headers = ["If-None-Match": etag]
        }
        
        sessionManager.request(urlRequest, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, nil, nil, nil, error) }
            case .success( _):
                guard let data = response.data, let imageOriginal = UIImage(data: data) else {
                    queue.async { completionHandler(account, nil, nil, nil, nil, .invalidData) }
                    return
                }
                let etag = NKCommon.shared.findHeader("etag", allHeaderFields:response.response?.allHeaderFields)?.replacingOccurrences(of: "\"", with: "")
                var imagePreview, imageIcon: UIImage?
                do {
                    if let data = imageOriginal.jpegData(compressionQuality: 0.5) {
                        try data.write(to: URL.init(fileURLWithPath: fileNamePreviewLocalPath), options: .atomic)
                        imagePreview = UIImage.init(data: data)
                    }
                    if fileNameIconLocalPath != nil && sizeIcon > 0 {
                        imageIcon =  imageOriginal.resizeImage(size: CGSize(width: sizeIcon, height: sizeIcon), isAspectRation: true)
                        if let data = imageIcon?.jpegData(compressionQuality: 0.5) {
                            try data.write(to: URL.init(fileURLWithPath: fileNameIconLocalPath!), options: .atomic)
                            imageIcon = UIImage.init(data: data)!
                        }
                    }
                    queue.async { completionHandler(account, imagePreview, imageIcon, imageOriginal, etag, .success) }
                } catch {
                    queue.async { completionHandler(account, nil, nil, nil, nil, NKError(error: error)) }
                }
            }
        }
    }
    
    @objc public func downloadAvatar(user: String, fileNameLocalPath: String, sizeImage: Int, avatarSizeRounded: Int = 0, etag: String?, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ imageAvatar: UIImage?, _ imageOriginal: UIImage?, _ etag: String?, _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account
        let endpoint = "index.php/avatar/" + user + "/\(sizeImage)"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, nil, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        var headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        if var etag = etag {
            etag = "\"" + etag + "\""
            headers = ["If-None-Match": etag]
        }
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, nil, nil, error) }
            case .success( _):
                if let data = response.data {
                    let imageOriginal = UIImage(data: data)
                    let etag = NKCommon.shared.findHeader("etag", allHeaderFields:response.response?.allHeaderFields)?.replacingOccurrences(of: "\"", with: "")
                    var imageAvatar: UIImage?
                    do {
                        let url = URL.init(fileURLWithPath: fileNameLocalPath)
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
                            let rect = CGRect(x: 0, y: 0, width: avatarSizeRounded/Int(UIScreen.main.scale), height: avatarSizeRounded/Int(UIScreen.main.scale))
                            UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
                            UIBezierPath.init(roundedRect: rect, cornerRadius: rect.size.height).addClip()
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
                        queue.async { completionHandler(account, imageAvatar, imageOriginal, etag, .success) }
                    } catch {
                        queue.async { completionHandler(account, nil, nil, nil, NKError(error: error)) }
                    }
                } else {
                    queue.async { completionHandler(account, nil, nil, nil, .invalidData) }
                }
            }
        }
    }
    
    @objc public func downloadContent(serverUrl: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account

        guard let url = serverUrl.asUrl else {
            return queue.async { completionHandler(account, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
              
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success( _):
                if let data = response.data {
                    queue.async { completionHandler(account, data, .success) }
                } else {
                    queue.async { completionHandler(account, nil, .invalidData) }
                }
            }
        }
    }
    
    //MARK: -
    
    @objc public func getUserProfile(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ userProfile: NKUserProfile?, _ error: NKError) -> Void) {
    
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/cloud/user?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
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
                    
                    queue.async { completionHandler(account, userProfile, .success) }
                    
                } else {
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    @objc public func getCapabilities(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ data: Data?, _ error: NKError) -> Void) {
    
        let account = NKCommon.shared.account
        let endpoint = "ocs/v1.php/cloud/capabilities?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success( _):
                if let data = response.data {
                    queue.async { completionHandler(account, data, .success) }
                } else {
                    queue.async { completionHandler(account, nil, .invalidData) }
                }
            }
        }
    }
    
    //MARK: -
    
    @objc public func getRemoteWipeStatus(serverUrl: String, token: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ wipe: Bool, _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account
        let endpoint = "index.php/core/wipe/check"
        let parameters: [String: Any] = ["token": token]

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return queue.async { completionHandler(account, false, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "POST")
                      
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, false, error) }
            case .success(let json):
                let json = JSON(json)
                let wipe = json["wipe"].boolValue
                queue.async { completionHandler(account, wipe, .success) }
            }
        }
    }
    
    @objc public func setRemoteWipeCompletition(serverUrl: String, token: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account
        let endpoint = "index.php/core/wipe/success"
        let parameters: [String: Any] = ["token": token]

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: serverUrl, endpoint: endpoint) else {
            return queue.async { completionHandler(account , .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "POST")
                 
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success( _):
                queue.async { completionHandler(account,.success) }
            }
        }
    }
    
    //MARK: -
    
    @objc public func getActivity(since: Int, limit: Int, objectId: String?, objectType: String?, previews: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ activities: [NKActivity], _ activityFirstKnown: Int, _ activityLastGiven: Int, _ error: NKError) -> Void) {
    
        let account = NKCommon.shared.account
        var activities: [NKActivity] = []
        var activityFirstKnown = 0
        var activityLastGiven = 0

        var endpoint = "ocs/v2.php/apps/activity/api/v2/activity/"
        var parameters: [String: Any] = [
            "format":"json",
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

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, activities, activityFirstKnown, activityLastGiven, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
       
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, activities, activityFirstKnown, 0, error) }
            case .success(let json):
                let json = JSON(json)
                let ocsdata = json["ocs"]["data"]
                for (_, subJson):(String, JSON) in ocsdata {
                    let activity = NKActivity()
                    
                    activity.app = subJson["app"].stringValue
                    activity.idActivity = subJson["activity_id"].intValue
                    if let datetime = subJson["datetime"].string {
                        if let date = NKCommon.shared.convertDate(datetime, format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
                            activity.date = date
                        }
                    }
                    activity.icon = subJson["icon"].stringValue
                    activity.link = subJson["link"].stringValue
                    activity.message = subJson["message"].stringValue
                    if subJson["message_rich"].exists() {
                        do {
                            activity.message_rich = try subJson["message_rich"].rawData()
                        } catch {}
                    }
                    activity.object_id = subJson["object_id"].intValue
                    activity.object_name = subJson["object_name"].stringValue
                    activity.object_type = subJson["object_type"].stringValue
                    if subJson["previews"].exists() {
                        do {
                            activity.previews = try subJson["previews"].rawData()
                        } catch {}
                    }
                    activity.subject = subJson["subject"].stringValue
                    if subJson["subject_rich"].exists() {
                        do {
                            activity.subject_rich = try subJson["subject_rich"].rawData()
                        } catch {}
                    }
                    activity.type = subJson["type"].stringValue
                    activity.user = subJson["user"].stringValue
                    
                    activities.append(activity)
                }

                let firstKnown: String = NKCommon.shared.findHeader("X-Activity-First-Known", allHeaderFields: response.response?.allHeaderFields) ?? "0"
                let lastGiven: String = NKCommon.shared.findHeader("X-Activity-Last-Given", allHeaderFields: response.response?.allHeaderFields) ?? "0"

                if let iFirstKnown = Int(firstKnown) { activityFirstKnown = iFirstKnown }
                if let ilastGiven = Int(lastGiven) { activityLastGiven = ilastGiven }

                queue.async { completionHandler(account, activities, activityFirstKnown, activityLastGiven, .success) }
            }
        }
    }
    
    //MARK: -
    
    @objc public func getNotifications(customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ notifications: [NKNotifications]?, _ error: NKError) -> Void) {
    
        let account = NKCommon.shared.account
        var notifications: [NKNotifications] = []
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/notifications?format=json"
        
        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "GET")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    let ocsdata = json["ocs"]["data"]
                    for (_, subJson):(String, JSON) in ocsdata {
                        let notification = NKNotifications()
                    
                        if subJson["actions"].exists() {
                            do {
                                notification.actions = try subJson["actions"].rawData()
                            } catch {}
                        }
                        notification.app = subJson["app"].stringValue
                        if let datetime = subJson["datetime"].string {
                            if let date = NKCommon.shared.convertDate(datetime, format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ") {
                                notification.date = date
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
                
                    queue.async { completionHandler(account, notifications, .success) }
                    
                } else {
                    
                    queue.async { completionHandler(account, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
    
    @objc public func setNotification(serverUrl: String?, idNotification: Int, method: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
                    
        let account = NKCommon.shared.account
        var url: URLConvertible?

        if serverUrl == nil {
            let endpoint = "ocs/v2.php/apps/notifications/api/v2/notifications/" + String(idNotification)
            url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint)
        } else {
            url = serverUrl!.asUrl
        }
        
        guard let urlRequest = url else {
            return queue.async { completionHandler(account, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: method)
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)

        sessionManager.request(urlRequest, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success( _):
                queue.async { completionHandler(account, .success) }
            }
        }
    }
    
    //MARK: -
    
    @objc public func getDirectDownload(fileId: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ url: String?, _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account
        let endpoint = "ocs/v2.php/apps/dav/api/v1/direct"
        let parameters: [String: Any] = [
            "fileId": fileId,
            "format": "json"
        ]

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint) else {
            return queue.async { completionHandler(account, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "POST")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        
        sessionManager.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let ocsdata = json["ocs"]["data"]
                let url = ocsdata["url"].string
                queue.async { completionHandler(account, url, .success) }
            }
        }
    }
}