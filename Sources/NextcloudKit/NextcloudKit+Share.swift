// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public class NKShareParameter: NSObject {
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

    /// - Parameters:
    ///   - path: Path to file or folder
    ///   - reshares: If set to false (default), only shares owned by the current user are returned. If set to true, shares owned by any user from the given file are returned.
    ///   - subfiles: If set to false (default), lists only the folder being shared. If set to true, all shared files within the folder are returned.
    ///   - sharedWithMe: (?) retrieve all shares, if set to true
    public init(path: String? = nil, reshares: Bool = false, subfiles: Bool = false, sharedWithMe: Bool = false) {
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
    public init(idShare: Int, reshares: Bool = false, subfiles: Bool = false, sharedWithMe: Bool = false) {
        self.path = nil
        self.idShare = idShare
        self.reshares = reshares
        self.subfiles = subfiles
        self.sharedWithMe = sharedWithMe
    }
}

public extension NextcloudKit {
    func readShares(parameters: NKShareParameter,
                    account: String,
                    options: NKRequestOptions = NKRequestOptions(),
                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                    completion: @escaping (_ account: String, _ shares: [NKShare]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: parameters.endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, parameters: parameters.queryParameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
        if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                guard json["ocs"]["meta"]["statuscode"].int == 200
                else {
                    let error = NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)
                    options.queue.async { completion(account, nil, response, error) }
                    return
                }
                var shares: [NKShare] = []
                for (_, subJson): (String, JSON) in json["ocs"]["data"] {
                    let share = self.convertResponseShare(json: subJson, account: account)
                    shares.append(share)
                }
                options.queue.async { completion(account, shares, response, .success) }
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
    func searchSharees(search: String = "",
                       page: Int = 1, perPage: Int = 200,
                       itemType: String = "file",
                       lookup: Bool = false,
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       completion: @escaping (_ account: String, _ sharees: [NKSharee]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/sharees"
        var lookupString = "false"
        if lookup {
            lookupString = "true"
        }
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters = [
            "search": search,
            "page": String(page),
            "perPage": String(perPage),
            "itemType": itemType,
            "lookup": lookupString
        ]

        nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
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
                                let date = Date(timeIntervalSince1970: clearAt)
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
                                let date = Date(timeIntervalSince1970: clearAt)
                                sharee.userClearAt = date
                            }
                            sharee.userIcon = subJson["status"]["icon"].stringValue
                            sharee.userMessage = subJson["status"]["message"].stringValue
                            sharee.userStatus = subJson["status"]["status"].stringValue

                            sharees.append(sharee)
                        }
                    }
                    options.queue.async { completion(account, sharees, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
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

    func createShareLink(path: String,
                         hideDownload: Bool = false,
                         publicUpload: Bool = false,
                         password: String? = nil,
                         permissions: Int = 1,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ share: NKShare?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        createShare(path: path, shareType: 3, shareWith: nil, publicUpload: publicUpload, hideDownload: hideDownload, password: password, permissions: permissions, account: account, options: options) { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        } completion: { account, share, responseData, error in
            completion(account, share, responseData, error)
        }
    }

    func createShare(path: String,
                     shareType: Int,
                     shareWith: String,
                     password: String? = nil,
                     note: String? = nil,
                     permissions: Int = 1,
                     attributes: String? = nil,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ share: NKShare?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        createShare(path: path, shareType: shareType, shareWith: shareWith, publicUpload: false, note: note, hideDownload: false, password: password, permissions: permissions, attributes: attributes, account: account, options: options) { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        } completion: { account, share, responseData, error in
            completion(account, share, responseData, error)
        }
    }

    private func createShare(path: String,
                             shareType: Int,
                             shareWith: String?,
                             publicUpload: Bool? = nil,
                             note: String? = nil,
                             hideDownload: Bool? = nil,
                             password: String? = nil,
                             permissions: Int = 1,
                             attributes: String? = nil,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ share: NKShare?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/shares"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        var parameters = [
            "path": path,
            "shareType": String(shareType),
            "permissions": String(permissions)
        ]
        if let shareWith {
            parameters["shareWith"] = shareWith
        }
        if let publicUpload {
            parameters["publicUpload"] = publicUpload ? "true" : "false"
        }
        if let note {
            parameters["note"] = note
        }
        if let hideDownload {
            parameters["hideDownload"] = hideDownload ? "true" : "false"
        }
        if let password {
            parameters["password"] = password
        }
        if let attributes {
            parameters["attributes"] = attributes
        }

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    options.queue.async { completion(account, self.convertResponseShare(json: json["ocs"]["data"], account: account), response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
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

    func updateShare(idShare: Int,
                     password: String? = nil,
                     expireDate: String? = nil,
                     permissions: Int = 1,
                     publicUpload: Bool? = nil,
                     note: String? = nil,
                     label: String? = nil,
                     hideDownload: Bool,
                     attributes: String? = nil,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ share: NKShare?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/shares/\(idShare)"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        var parameters = [
            "permissions": String(permissions)
        ]
        if let password, !password.isEmpty {
            parameters["password"] = password
        }
        if let expireDate, !expireDate.isEmpty {
            parameters["expireDate"] = expireDate
        }
        if let note, !note.isEmpty {
            parameters["note"] = note
        }
        if let label, !label.isEmpty {
            parameters["label"] = label
        }

        if let publicUpload {
            parameters["publicUpload"] = publicUpload ? "true" : "false"
        }

        parameters["hideDownload"] = hideDownload ? "true" : "false"
        if let attributes = attributes {
            parameters["attributes"] = attributes
        }

        nkSession.sessionData.request(url, method: .put, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if statusCode == 200 {
                    options.queue.async { completion(account, self.convertResponseShare(json: json["ocs"]["data"], account: account), response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /*
    * @param idShare: Identifier of the share to update
    */
    func deleteShare(idShare: Int,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data?>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/shares/\(idShare)"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
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

    private func convertResponseShare(json: JSON, account: String) -> NKShare {
        let share = NKShare()

        share.account = account
        share.canDelete = json["can_delete"].boolValue
        share.canEdit = json["can_edit"].boolValue
        share.displaynameFileOwner = json["displayname_file_owner"].stringValue
        share.displaynameOwner = json["displayname_owner"].stringValue
        if let expiration = json["expiration"].string, let date = self.nkCommonInstance.convertDate(expiration, format: "YYYY-MM-dd HH:mm:ss") {
            share.expirationDate = date as NSDate
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
            let date = Date(timeIntervalSince1970: stime)
            share.date = date
        }
        share.storage = json["storage"].intValue
        share.storageId = json["storage_id"].stringValue
        share.token = json["token"].stringValue
        share.uidFileOwner = json["uid_file_owner"].stringValue
        share.uidOwner = json["uid_owner"].stringValue
        share.url = json["url"].stringValue
        if let clearAt = json["status"]["clearAt"].double {
            let date = Date(timeIntervalSince1970: clearAt)
            share.userClearAt = date
        }
        share.userIcon = json["status"]["icon"].stringValue
        share.userMessage = json["status"]["message"].stringValue
        share.userStatus = json["status"]["status"].stringValue
        share.attributes = json["attributes"].string

        return share
    }
}

public class NKShare: NSObject {
    public var account = ""
    public var canEdit: Bool = false
    public var canDelete: Bool = false
    public var date: Date?
    public var displaynameFileOwner = ""
    public var displaynameOwner = ""
    public var expirationDate: NSDate?
    public var fileParent: Int = 0
    public var fileSource: Int = 0
    public var fileTarget = ""
    public var hideDownload: Bool = false
    public var idShare: Int = 0
    public var itemSource: Int = 0
    public var itemType = ""
    public var label = ""
    public var mailSend: Bool = false
    public var mimeType = ""
    public var note = ""
    public var parent = ""
    public var password = ""
    public var path = ""
    public var permissions: Int = 0
    public var sendPasswordByTalk: Bool = false
    public var shareType: Int = 0
    public var shareWith = ""
    public var shareWithDisplayname = ""
    public var storage: Int = 0
    public var storageId = ""
    public var token = ""
    public var uidFileOwner = ""
    public var uidOwner = ""
    public var url = ""
    public var userClearAt: Date?
    public var userIcon = ""
    public var userMessage = ""
    public var userStatus = ""
    public var attributes: String?
}
