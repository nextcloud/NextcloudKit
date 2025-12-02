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
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: parameters.endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, parameters: parameters.queryParameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously reads shares for a given account using the provided parameters.
    /// - Parameters:
    ///   - parameters: The `NKShareParameter` object containing filters and options for the request.
    ///   - account: The account identifier for which to fetch shares.
    ///   - options: Optional `NKRequestOptions` to customize the request (default is empty).
    ///   - taskHandler: Closure called when the underlying `URLSessionTask` is created, useful for tracking or cancellation.
    /// - Returns: A tuple containing:
    ///   - `account`: The account used for the request.
    ///   - `shares`: An optional array of `NKShare` objects returned by the server.
    ///   - `responseData`: The raw Alamofire response object.
    ///   - `error`: An `NKError` indicating the result of the request.
    func readSharesAsync(parameters: NKShareParameter,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, shares: [NKShare]?, responseData: AFDataResponse<Data>?, error: NKError) {

        await withCheckedContinuation { continuation in
            readShares(
                parameters: parameters,
                account: account,
                options: options,
                taskHandler: taskHandler
            ) { account, shares, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    shares: shares,
                    responseData: responseData,
                    error: error
                ))
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
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

    /// Searches for sharees (users, groups, etc.) that can be shared with, using the provided parameters.
    /// This function performs a paginated server-side lookup of sharees for a given account.
    /// - Parameters:
    ///   - search: The search string used to filter sharees (default is empty string).
    ///   - page: The current page for pagination (default is 1).
    ///   - perPage: The number of results per page (default is 200).
    ///   - itemType: The type of item to be shared (e.g., "file").
    ///   - lookup: Whether to enable extended lookup on the server (default is false).
    ///   - account: The account identifier associated with the request.
    ///   - options: Optional request parameters (default is `.init()`).
    /// - Returns: A tuple containing:
    ///   - account: The associated account string.
    ///   - sharees: An optional array of `NKSharee` objects returned by the server.
    ///   - responseData: The full `AFDataResponse<Data>` from Alamofire.
    ///   - error: An `NKError` object representing success or failure.
    func searchShareesAsync(
        search: String = "",
        page: Int = 1,
        perPage: Int = 200,
        itemType: String = "file",
        lookup: Bool = false,
        account: String,
        options: NKRequestOptions = NKRequestOptions()
    ) async -> (
        account: String,
        sharees: [NKSharee]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            searchSharees(
                search: search,
                page: page,
                perPage: perPage,
                itemType: itemType,
                lookup: lookup,
                account: account,
                options: options,
                taskHandler: { _ in },
                completion: { account, sharees, responseData, error in
                    continuation.resume(returning: (
                        account: account,
                        sharees: sharees,
                        responseData: responseData,
                        error: error
                    ))
                }
            )
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

    func createShare(path: String,
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
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

    /// Creates a new share for the specified path and parameters, such as share type, target, permissions, and options.
    /// This function performs a network request to the server to create the share.
    /// - Parameters:
    ///   - path: The file or folder path to be shared.
    ///   - shareType: The type of share (e.g., 0=user, 1=group, 3=public link).
    ///   - shareWith: The recipient (username, group name, or nil for public).
    ///   - publicUpload: Whether to allow public upload (if applicable).
    ///   - note: Optional note associated with the share.
    ///   - hideDownload: Whether to hide the download option (if supported).
    ///   - password: Optional password for protected shares.
    ///   - permissions: Bitmask representing share permissions (default is 1 = read).
    ///   - attributes: Optional extended attributes as string.
    ///   - account: The account making the request.
    ///   - options: Optional request options (default is `.init()`).
    /// - Returns: A tuple containing:
    ///   - account: The account string.
    ///   - share: An optional `NKShare` object representing the created share.
    ///   - responseData: The raw `AFDataResponse<Data>` returned by Alamofire.
    ///   - error: An `NKError` representing the result of the operation.
    func createShareAsync(
        path: String,
        shareType: Int,
        shareWith: String?,
        publicUpload: Bool? = nil,
        note: String? = nil,
        hideDownload: Bool? = nil,
        password: String? = nil,
        permissions: Int = 1,
        attributes: String? = nil,
        account: String,
        options: NKRequestOptions = NKRequestOptions()
    ) async -> (
        account: String,
        share: NKShare?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            createShare(
                path: path,
                shareType: shareType,
                shareWith: shareWith,
                publicUpload: publicUpload,
                note: note,
                hideDownload: hideDownload,
                password: password,
                permissions: permissions,
                attributes: attributes,
                account: account,
                options: options,
                taskHandler: { _ in },
                completion: { account, share, responseData, error in
                    continuation.resume(returning: (
                        account: account,
                        share: share,
                        responseData: responseData,
                        error: error
                    ))
                }
            )
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
                     expireDate: String? = "",
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
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        var parameters = [
            "permissions": String(permissions)
        ]

        parameters["password"] = password != nil ? password : ""
        
        parameters["expireDate"] = expireDate != nil ? expireDate : ""

        if let note {
            parameters["note"] = note
        }
        
        if let label {
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

    /// Updates the parameters of an existing share identified by its ID.
    /// Allows changing settings like password, expiration, permissions, public upload, note, label, etc.
    /// - Parameters:
    ///   - idShare: The ID of the share to be updated.
    ///   - password: Optional new password for the share.
    ///   - expireDate: Optional new expiration date (in string format).
    ///   - permissions: Bitmask representing new share permissions (default is 1 = read).
    ///   - publicUpload: Whether public upload is enabled for the share.
    ///   - note: Optional note for the share.
    ///   - label: Optional label for identifying the share.
    ///   - hideDownload: Whether the download option should be hidden.
    ///   - attributes: Optional string of encoded attributes.
    ///   - account: The account performing the update.
    ///   - options: Optional request options (default is `.init()`).
    /// - Returns: A tuple containing:
    ///   - account: The account string.
    ///   - share: The updated `NKShare` object, or nil on failure.
    ///   - responseData: The raw `AFDataResponse<Data>` returned by Alamofire.
    ///   - error: An `NKError` representing the outcome of the operation.
    func updateShareAsync(
        idShare: Int,
        password: String? = nil,
        expireDate: String? = nil,
        permissions: Int = 1,
        publicUpload: Bool? = nil,
        note: String? = nil,
        label: String? = nil,
        hideDownload: Bool,
        attributes: String? = nil,
        account: String,
        options: NKRequestOptions = NKRequestOptions()
    ) async -> (
        account: String,
        share: NKShare?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            updateShare(
                idShare: idShare,
                password: password,
                expireDate: expireDate,
                permissions: permissions,
                publicUpload: publicUpload,
                note: note,
                label: label,
                hideDownload: hideDownload,
                attributes: attributes,
                account: account,
                options: options,
                taskHandler: { _ in },
                completion: { account, share, responseData, error in
                    continuation.resume(returning: (
                        account: account,
                        share: share,
                        responseData: responseData,
                        error: error
                    ))
                }
            )
        }
    }

    /*
    * @param idShare: Identifier of the share to update
    */
    func deleteShare(idShare: Int,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/files_sharing/api/v1/shares/\(idShare)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            let result = self.evaluateResponse(response)

            options.queue.async {
                completion(account, response, result)
            }
        }
    }

    /// Deletes an existing share on the server using its share ID.
    /// This function sends a network request to remove the share for the specified account.
    /// - Parameters:
    ///   - idShare: The ID of the share to delete.
    ///   - account: The account initiating the deletion request.
    ///   - options: Optional request options (default is `.init()`).
    /// - Returns: A tuple containing:
    ///   - account: The account string used for the request.
    ///   - responseData: The full `AFDataResponse<Data>` returned from the server.
    ///   - error: An `NKError` representing the result of the deletion operation.
    func deleteShareAsync(
        idShare: Int,
        account: String,
        options: NKRequestOptions = NKRequestOptions()
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            deleteShare(
                idShare: idShare,
                account: account,
                options: options,
                taskHandler: { _ in },
                completion: { account, responseData, error in
                    continuation.resume(returning: (
                        account: account,
                        responseData: responseData,
                        error: error
                    ))
                }
            )
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
        if let expiration = json["expiration"].string, let date = expiration.parsedDate(using: "YYYY-MM-dd HH:mm:ss") {
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
