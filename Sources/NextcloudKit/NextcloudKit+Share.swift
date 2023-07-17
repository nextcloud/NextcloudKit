//
//  NextcloudKit+Share.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 15/06/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

import Foundation
import Alamofire
import SwiftyJSON

@objc public class NKShareParameter: NSObject {

    /// - Parameters:
    ///   - path: Path to file or folder
    ///   - reshares: If set to false (default), only shares owned by the current user are returned. If set to true, shares owned by any user from the given file are returned.
    ///   - subfiles: If set to false (default), lists only the folder being shared. If set to true, all shared files within the folder are returned.
    ///   - sharedWithMe: (?) retrieve all shares, if set to true
    @objc public init(path: String? = nil, reshares: Bool = false, subfiles: Bool = false, sharedWithMe: Bool = false) {
        self.path = path
        self.idShare = 0
        self.reshares = reshares
        self.subfiles = subfiles
        self.sharedWithMe = sharedWithMe
    }

    /// - Parameters:
    ///   - idShare: Identifier of the share to update
    ///   - reshares: If set to false (default), only shares owned by the current user are returned. If set to true, shares owned by any user from the given file are returned.
    ///   - subfiles: If set to false (default), lists only the folder being shared. If set to true, all shared files within the folder are returned.
    ///   - sharedWithMe: (?) retrieve all shares, if set to true
    @objc public init(idShare: Int, reshares: Bool = false, subfiles: Bool = false, sharedWithMe: Bool = false) {
        self.path = nil
        self.idShare = idShare
        self.reshares = reshares
        self.subfiles = subfiles
        self.sharedWithMe = sharedWithMe
    }

    let path: String?
    let idShare: Int
    let reshares: Bool
    let subfiles: Bool
    let sharedWithMe: Bool

    internal var endpoint: String {
        guard idShare > 0 else {
             return "ocs/v2.php/apps/files_sharing/api/v1/shares"
        }
        return "ocs/v2.php/apps/files_sharing/api/v1/shares/\(idShare)"
    }

    internal var queryParameters: [String: String] {
        var parameters = [
            "reshares": reshares ? "true" : "false",
            "subfiles": subfiles ? "true" : "false",
            "shared_with_me": sharedWithMe ? "true" : "false"
        ]
        parameters["path"] = path
        return parameters
    }
}

extension NextcloudKit {

    @objc public func readShares(parameters: NKShareParameter,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 completion: @escaping (_ account: String, _ shares: [NKShare]?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: parameters.endpoint)
        else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: parameters.queryParameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
        debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                guard json["ocs"]["meta"]["statuscode"].int == 200
                else {
                    let error = NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)
                    options.queue.async { completion(account, nil, jsonData, error) }
                    return
                }
                var shares: [NKShare] = []
                for (_, subJson): (String, JSON) in json["ocs"]["data"] {
                    let share = self.convertResponseShare(json: subJson)
                    shares.append(share)
                }
                options.queue.async { completion(account, shares, jsonData, .success) }
            }
        }
    }

    /*
    * @param search         The search string
    * @param itemType       The type which is shared (e.g. file or folder)
    * @param shareType      Any of the shareTypes (0 = user; 1 = group; 3 = public link; 6 = federated cloud share)
    * @param page           The page number to be returned (default 1)
    * @param perPage        The number of items per page (default 200)
    * @param lookup         Default false, for global search use true
    */

    @objc public func searchSharees(search: String = "",
                                    page: Int = 1, perPage: Int = 200,
                                    itemType: String = "file",
                                    lookup: Bool = false,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    completion: @escaping (_ account: String, _ sharees: [NKSharee]?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/sharees"

        var lookupString = "false"
        if lookup {
            lookupString = "true"
        }

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        let parameters = [
            "search": search,
            "page": String(page),
            "perPage": String(perPage),
            "itemType": itemType,
            "lookup": lookupString
        ]

        sessionManager.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)

                if json["ocs"]["meta"]["statuscode"].int == 200 {
                    var sharees: [NKSharee] = []
                    for shareType in ["users", "groups", "remotes", "remote_groups", "emails", "circles", "rooms", "lookup"] {
                        for (_, subJson): (String, JSON) in json["ocs"]["data"]["exact"][shareType] {
                            let sharee = NKSharee()

                            sharee.label = subJson["label"].stringValue
                            sharee.name = subJson["name"].stringValue
                            sharee.uuid = subJson["uuid"].stringValue

                            sharee.shareType = subJson["value"]["shareType"].intValue
                            sharee.shareWith = subJson["value"]["shareWith"].stringValue

                            sharee.circleInfo = subJson["value"]["circleInfo"].stringValue
                            sharee.circleOwner = subJson["value"]["circleOwner"].stringValue

                            if let clearAt = subJson["status"]["clearAt"].double {
                                let date = Date(timeIntervalSince1970: clearAt) as NSDate
                                sharee.userClearAt = date
                            }
                            sharee.userIcon = subJson["status"]["icon"].stringValue
                            sharee.userMessage = subJson["status"]["message"].stringValue
                            sharee.userStatus = subJson["status"]["status"].stringValue

                            sharees.append(sharee)
                        }
                        for (_, subJson): (String, JSON) in json["ocs"]["data"][shareType] {
                            let sharee = NKSharee()

                            sharee.label = subJson["label"].stringValue
                            sharee.name = subJson["name"].stringValue
                            sharee.uuid = subJson["uuid"].stringValue

                            sharee.shareType = subJson["value"]["shareType"].intValue
                            sharee.shareWith = subJson["value"]["shareWith"].stringValue

                            sharee.circleInfo = subJson["value"]["circleInfo"].stringValue
                            sharee.circleOwner = subJson["value"]["circleOwner"].stringValue

                            if let clearAt = subJson["status"]["clearAt"].double {
                                let date = Date(timeIntervalSince1970: clearAt) as NSDate
                                sharee.userClearAt = date
                            }
                            sharee.userIcon = subJson["status"]["icon"].stringValue
                            sharee.userMessage = subJson["status"]["message"].stringValue
                            sharee.userStatus = subJson["status"]["status"].stringValue

                            sharees.append(sharee)
                        }
                    }
                    options.queue.async { completion(account, sharees, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /*
    * @param path           path of the file/folder being shared. Mandatory argument
    * @param shareType      0 = user, 1 = group, 3 = Public link. Mandatory argument
    * @param shareWith      User/group ID with who the file should be shared.  This is mandatory for shareType of 0 or 1
    * @param publicUpload   If false (default) public cannot upload to a public shared folder. If true public can upload to a shared folder. Only available for public link shares
    * @param hideDownload   Permission if file can be downloaded via share link (only for single file)
    * @param password       Password to protect a public link share. Only available for public link shares
    * @param permissions    1 - Read only Default for public shares
    *                       2 - Update
    *                       4 - Create
    *                       8 - Delete
    *                       16- Re-share
    *                       31- All above Default for private shares
    *                       For user or group shares.
    *                       To obtain combinations, add the desired values together.
    *                       For instance, for Re-Share, delete, read, update, add 16+8+2+1 = 27.
    * @param attributes     There is currently only one share attribute “download” from the scope “permissions”. This attribute is only valid for user and group shares, not for public link shares.
    */

    @objc public func createShareLink(path: String,
                                      hideDownload: Bool = false,
                                      publicUpload: Bool = false,
                                      password: String? = nil,
                                      permissions: Int = 1,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      completion: @escaping (_ account: String, _ share: NKShare?, _ data: Data?, _ error: NKError) -> Void) {

        createShare(path: path, shareType: 3, shareWith: nil, publicUpload: publicUpload, hideDownload: hideDownload, password: password, permissions: permissions, options: options, completion: completion)
    }

    @objc public func createShare(path: String,
                                  shareType: Int,
                                  shareWith: String,
                                  password: String? = nil,
                                  permissions: Int = 1,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  attributes: String? = nil,
                                  completion: @escaping (_ account: String, _ share: NKShare?, _ data: Data?, _ error: NKError) -> Void) {

        createShare(path: path, shareType: shareType, shareWith: shareWith, publicUpload: false, hideDownload: false, password: password, permissions: permissions, attributes: attributes, options: options, completion: completion)
    }

    private func createShare(path: String,
                             shareType: Int,
                             shareWith: String?,
                             publicUpload: Bool? = nil,
                             hideDownload: Bool? = nil,
                             password: String? = nil,
                             permissions: Int = 1,
                             attributes: String? = nil,
                             options: NKRequestOptions = NKRequestOptions(),
                             completion: @escaping (_ account: String, _ share: NKShare?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/shares"

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        var parameters = [
            "path": path,
            "shareType": String(shareType),
            "permissions": String(permissions)
        ]
        if let shareWith = shareWith {
            parameters["shareWith"] = shareWith
        }
        if let publicUpload = publicUpload {
            parameters["publicUpload"] = publicUpload ? "true" : "false"
        }
        if let hideDownload = hideDownload {
            parameters["hideDownload"] = hideDownload ? "true" : "false"
        }
        if let password = password {
            parameters["password"] = password
        }
        if let attributes = attributes {
            parameters["attributes"] = attributes
        }

        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    options.queue.async { completion(account, self.convertResponseShare(json: json["ocs"]["data"]), jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /*
    * @param idShare        Identifier of the share to update
    * @param password       Password to protect a public link share. Only available for public link shares, Empty string clears the current password, Null results in no update applied to the password
    * @param expireDate
    * @param permissions    1 - Read only Default for public shares
    *                       2 - Update
    *                       4 - Create
    *                       8 - Delete
    *                       16- Re-share
    *                       31- All above Default for private shares
    *                       For user or group shares.
    *                       To obtain combinations, add the desired values together.
    *                       For instance, for Re-Share, delete, read, update, add 16+8+2+1 = 27.
    * @param publicUpload   If false (default) public cannot upload to a public shared folder. If true public can upload to a shared folder. Only available for public link shares
    * @param note           Note
    * @param label          Label
    * @param hideDownload   Permission if file can be downloaded via share link (only for single file)
    * @param attributes     There is currently only one share attribute “download” from the scope “permissions”. This attribute is only valid for user and group shares, not for public link shares.
    */

    @objc public func updateShare(idShare: Int,
                                  password: String? = nil,
                                  expireDate: String? = nil,
                                  permissions: Int = 1,
                                  publicUpload: Bool = false,
                                  note: String? = nil,
                                  label: String? = nil,
                                  hideDownload: Bool,
                                  attributes: String? = nil,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  completion: @escaping (_ account: String, _ share: NKShare?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/shares/\(idShare)"

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        var parameters = [
            "permissions": String(permissions)
        ]
        if let password = password {
            parameters["password"] = password
        }
        if let expireDate = expireDate {
            parameters["expireDate"] = expireDate
        }
        if let note = note {
            parameters["note"] = note
        }
        if let label = label {
            parameters["label"] = label
        }
        parameters["publicUpload"] = publicUpload ? "true" : "false"
        parameters["hideDownload"] = hideDownload ? "true" : "false"
        if let attributes = attributes {
            parameters["attributes"] = attributes
        } else {
            parameters["attributes"] = "[]"
        }

        sessionManager.request(url, method: .put, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    options.queue.async { completion(account, self.convertResponseShare(json: json["ocs"]["data"]), jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /*
    * @param idShare        Identifier of the share to update
    */

    @objc public func deleteShare(idShare: Int,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  completion: @escaping (_ account: String, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/shares/\(idShare)"

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .delete, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

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

    private func convertResponseShare(json: JSON) -> NKShare {
        let share = NKShare()

        share.account = self.nkCommonInstance.account
        share.canDelete = json["can_delete"].boolValue
        share.canEdit = json["can_edit"].boolValue
        share.displaynameFileOwner = json["displayname_file_owner"].stringValue
        share.displaynameOwner = json["displayname_owner"].stringValue
        if let expiration = json["expiration"].string, let date = self.nkCommonInstance.convertDate(expiration, format: "YYYY-MM-dd HH:mm:ss") {
            share.expirationDate = date
        }
        share.fileParent = json["file_parent"].intValue
        share.fileSource = json["file_source"].intValue
        share.fileTarget = json["file_target"].stringValue
        share.hideDownload = json["hide_download"].boolValue
        share.idShare = json["id"].intValue
        share.itemSource = json["item_source"].intValue
        share.itemType = json["item_type"].stringValue
        share.label = json["label"].stringValue
        share.mailSend = json["mail_send"].boolValue
        share.mimeType = json["mimetype"].stringValue
        share.note = json["note"].stringValue
        share.parent = json["parent"].stringValue
        share.password = json["password"].stringValue
        share.path = json["path"].stringValue
        share.permissions = json["permissions"].intValue
        share.sendPasswordByTalk = json["send_password_by_talk"].boolValue
        share.shareType = json["share_type"].intValue
        share.shareWith = json["share_with"].stringValue
        share.shareWithDisplayname = json["share_with_displayname"].stringValue
        if let stime = json["stime"].double {
            let date = Date(timeIntervalSince1970: stime) as NSDate
            share.date = date
        }
        share.storage = json["storage"].intValue
        share.storageId = json["storage_id"].stringValue
        share.token = json["token"].stringValue
        share.uidFileOwner = json["uid_file_owner"].stringValue
        share.uidOwner = json["uid_owner"].stringValue
        share.url = json["url"].stringValue
        if let clearAt = json["status"]["clearAt"].double {
            let date = Date(timeIntervalSince1970: clearAt) as NSDate
            share.userClearAt = date
        }
        share.userIcon = json["status"]["icon"].stringValue
        share.userMessage = json["status"]["message"].stringValue
        share.userStatus = json["status"]["status"].stringValue
        share.attributes = json["attributes"].string

        return share
    }
}

@objc public class NKShare: NSObject {

    @objc public var account = ""
    @objc public var canEdit: Bool = false
    @objc public var canDelete: Bool = false
    @objc public var date: NSDate?
    @objc public var displaynameFileOwner = ""
    @objc public var displaynameOwner = ""
    @objc public var expirationDate: NSDate?
    @objc public var fileParent: Int = 0
    @objc public var fileSource: Int = 0
    @objc public var fileTarget = ""
    @objc public var hideDownload: Bool = false
    @objc public var idShare: Int = 0
    @objc public var itemSource: Int = 0
    @objc public var itemType = ""
    @objc public var label = ""
    @objc public var mailSend: Bool = false
    @objc public var mimeType = ""
    @objc public var note = ""
    @objc public var parent = ""
    @objc public var password = ""
    @objc public var path = ""
    @objc public var permissions: Int = 0
    @objc public var sendPasswordByTalk: Bool = false
    @objc public var shareType: Int = 0
    @objc public var shareWith = ""
    @objc public var shareWithDisplayname = ""
    @objc public var storage: Int = 0
    @objc public var storageId = ""
    @objc public var token = ""
    @objc public var uidFileOwner = ""
    @objc public var uidOwner = ""
    @objc public var url = ""
    @objc public var userClearAt: NSDate?
    @objc public var userIcon = ""
    @objc public var userMessage = ""
    @objc public var userStatus = ""
    @objc public var attributes: String?
}
