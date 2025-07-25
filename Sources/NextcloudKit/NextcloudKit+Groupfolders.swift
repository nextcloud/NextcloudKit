// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Henrik Storch
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Retrieves the list of available group folders for the given Nextcloud account.
    /// Group folders are shared spaces available across users and groups,
    /// managed via the groupfolders app.
    ///
    /// Parameters:
    /// - account: The Nextcloud account requesting the list of group folders.
    /// - options: Optional request options (e.g., API version, custom headers, queue).
    /// - taskHandler: Closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, list of group folders, response, and any NKError.
    func getGroupfolders(account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ results: [NKGroupfolders]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/apps/groupfolders/folders?applicable=1"
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
                let data = json["ocs"]["data"]
                guard json["ocs"]["meta"]["statuscode"].int == 200 || json["ocs"]["meta"]["statuscode"].int == 100
                else {
                    let error = NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)
                    options.queue.async { completion(account, nil, response, error) }
                    return
                }
                var results = [NKGroupfolders]()
                for (_, subJson) in data {
                    if let result = NKGroupfolders(json: subJson) {
                        results.append(result)
                    }
                }
                options.queue.async { completion(account, results, response, .success) }
            }
        }
    }

    /// Asynchronously retrieves the list of Groupfolders associated with the given account.
    /// - Parameters:
    ///   - account: The Nextcloud account identifier.
    ///   - options: Optional request configuration (headers, queue, etc.).
    ///   - taskHandler: Optional monitoring of the `URLSessionTask`.
    /// - Returns: A tuple containing the account, an optional array of `NKGroupfolders`, the response data, and an `NKError`.
    func getGroupfoldersAsync(account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        results: [NKGroupfolders]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getGroupfolders(account: account,
                            options: options,
                            taskHandler: taskHandler) { account, results, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    results: results,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
}

public class NKGroupfolders: NSObject {
    public let id: Int
    public let mountPoint: String
    public let acl: Bool
    public let size: Int
    public let quota: Int
    public let manage: Data?
    public let groups: [String: Any]?

    init?(json: JSON) {
        guard let id = json["id"].int,
              let mountPoint = json["mount_point"].string,
              let acl = json["acl"].bool,
              let size = json["size"].int,
              let quota = json["quota"].int
        else { return nil }

        self.id = id
        self.mountPoint = mountPoint
        self.acl = acl
        self.size = size
        self.quota = quota
        do {
            let data = try json["manage"].rawData()
            self.manage = data
        } catch {
            self.manage = nil
        }
        self.groups = json["groups"].dictionaryObject
    }
}
