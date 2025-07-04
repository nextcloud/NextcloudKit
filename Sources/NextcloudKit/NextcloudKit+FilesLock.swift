// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Sorch
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Sends a WebDAV LOCK or UNLOCK request for a file on the server,
    /// depending on the `shouldLock` flag. This is used to prevent or release
    /// concurrent edits on a file.
    ///
    /// Parameters:
    /// - serverUrlFileName: Fully qualified and encoded URL of the file to lock/unlock.
    /// - shouldLock: Pass `true` to lock the file, `false` to unlock it.
    /// - account: The Nextcloud account performing the operation.
    /// - options: Optional request options (e.g. headers, queue).
    /// - taskHandler: Closure to access the URLSessionTask.
    /// - completion: Completion handler returning the account, response, and NKError.
    func lockUnlockFile(serverUrlFileName: String,
                        shouldLock: Bool,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlFileName.encodedToUrl
        else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: shouldLock ? "LOCK" : "UNLOCK")
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        headers.update(name: "X-User-Lock", value: "1")

        nkSession.sessionData.request(url, method: method, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    /// Asynchronously locks or unlocks a file on the server via WebDAV.
    /// - Parameters:
    ///   - serverUrlFileName: The server-side full URL of the file to lock or unlock.
    ///   - shouldLock: `true` to lock the file, `false` to unlock it.
    ///   - account: The Nextcloud account performing the action.
    ///   - options: Optional request configuration (headers, queue, etc.).
    ///   - taskHandler: Optional monitoring of the `URLSessionTask`.
    /// - Returns: A tuple containing the account, the server response, and any error encountered.
    func lockUnlockFileAsync(serverUrlFileName: String,
                             shouldLock: Bool,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            lockUnlockFile(serverUrlFileName: serverUrlFileName,
                           shouldLock: shouldLock,
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
