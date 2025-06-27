// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    // Marks or unmarks a folder as End-to-End Encrypted (E2EE) for a given Nextcloud account.
    // Depending on the `delete` flag, this function either enables or disables the E2EE status for the folder.
    //
    // Parameters:
    // - fileId: The identifier of the folder to mark/unmark.
    // - delete: If `true`, removes the E2EE mark; if `false`, adds the E2EE mark.
    // - account: The Nextcloud account performing the operation.
    // - options: Optional request options (default is empty).
    // - taskHandler: Closure to access the `URLSessionTask` (default is no-op).
    // - completion: Completion handler returning the account, raw response, and any NKError.
    func markE2EEFolder(fileId: String,
                        delete: Bool,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/encrypted/\(fileId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method: HTTPMethod = delete ? .delete : .put

        nkSession.sessionData.request(url, method: method, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    options.queue.async { completion(account, response, .success) }
                } else {
                    options.queue.async { completion(account, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously marks or unmarks a folder as E2EE for the specified account.
    /// - Parameters:
    ///   - fileId: The ID of the folder.
    ///   - delete: Whether to remove (`true`) or set (`false`) the E2EE mark.
    ///   - account: The account performing the request.
    ///   - options: Optional request options (default is empty).
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple containing the account, raw response, and NKError.
    func markE2EEFolderAsync(fileId: String,
                             delete: Bool,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            markE2EEFolder(fileId: fileId,
                           delete: delete,
                           account: account,
                           options: options,
                           taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (account, responseData, error))
            }
        }
    }

    // Locks or unlocks a folder for End-to-End Encryption (E2EE) using a provided token and counter.
    // Depending on the HTTP `method` (e.g. "LOCK", "UNLOCK", "PUT"), the operation will either lock the folder,
    // refresh the E2EE token, or perform another action defined by the server API.
    //
    // Parameters:
    // - fileId: The identifier of the folder to lock or unlock.
    // - e2eToken: Optional E2EE token used to lock the folder (nil if unlocking).
    // - e2eCounter: Optional counter value for token freshness or verification.
    // - method: The HTTP method to use for the request (e.g., "LOCK", "PUT", etc.).
    // - account: The Nextcloud account performing the request.
    // - options: Optional request options (default is empty).
    // - taskHandler: Closure to access the `URLSessionTask` (default is no-op).
    // - completion: Completion handler returning the account, updated E2EE token, raw response, and any NKError.
    func lockE2EEFolder(fileId: String,
                        e2eToken: String?,
                        e2eCounter: String?,
                        method: String,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                        completion: @escaping (_ account: String, _ e2eToken: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/lock/\(fileId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: method)
        var parameters: [String: Any] = [:]

        if let e2eToken {
            headers.update(name: "e2e-token", value: e2eToken)
            parameters = ["e2e-token": e2eToken]
        }
        if let e2eCounter {
            headers.update(name: "X-NC-E2EE-COUNTER", value: e2eCounter)
        }

        nkSession.sessionData.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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
                if 200..<300 ~= statusCode {
                    let e2eToken = json["ocs"]["data"]["e2e-token"].string
                    options.queue.async { completion(account, e2eToken, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously locks or unlocks an E2EE folder for the given account using the specified method and token.
    /// - Parameters:
    ///   - fileId: The ID of the folder to lock/unlock.
    ///   - e2eToken: Optional E2EE token to lock the folder (nil for unlock).
    ///   - e2eCounter: Optional counter value (used for token freshness).
    ///   - method: The HTTP method to use (e.g. "LOCK", "PUT").
    ///   - account: The account performing the operation.
    ///   - options: Optional request options (default is empty).
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with the account, resulting E2EE token (if any), raw response, and NKError.
    func lockE2EEFolderAsync(fileId: String,
                             e2eToken: String?,
                             e2eCounter: String?,
                             method: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, String?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            lockE2EEFolder(fileId: fileId,
                           e2eToken: e2eToken,
                           e2eCounter: e2eCounter,
                           method: method,
                           account: account,
                           options: options,
                           taskHandler: taskHandler) { account, e2eToken, responseData, error in
                continuation.resume(returning: (account, e2eToken, responseData, error))
            }
        }
    }

    // Retrieves E2EE metadata and signature for a specific file from the Nextcloud E2EE API.
    // It supports different API versions via the `options.version` property (default is "v1").
    // This request is authenticated and validated, and returns both metadata and signature
    // (from header `X-NC-E2EE-SIGNATURE`) if the operation is successful.
    //
    // Parameters:
    // - fileId: The file identifier to retrieve metadata for.
    // - e2eToken: Optional E2EE token used for authorization or context.
    // - account: The Nextcloud account performing the request.
    // - options: Optional request options (includes version, queue, task description, etc.).
    // - taskHandler: Closure to access the URLSessionTask for progress or control.
    // - completion: Completion handler returning the account, metadata string, signature string, response, and NKError.
    func getE2EEMetadata(fileId: String,
                         e2eToken: String?,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ e2eMetadata: String?, _ signature: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/meta-data/\(fileId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, .urlError) }
        }
        var parameters: [String: Any] = [:]
        if let e2eToken {
            parameters["e2e-token"] = e2eToken
        }

        nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let e2eMetadata = json["ocs"]["data"]["meta-data"].string
                    let signature = response.response?.allHeaderFields["X-NC-E2EE-SIGNATURE"] as? String
                    options.queue.async { completion(account, e2eMetadata, signature, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves E2EE metadata and signature for a specific file.
    /// - Parameters:
    ///   - fileId: The ID of the file to retrieve metadata for.
    ///   - e2eToken: Optional E2EE token.
    ///   - account: The Nextcloud account requesting metadata.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the task.
    /// - Returns: A tuple containing the account, E2EE metadata, signature, raw response, and NKError.
    func getE2EEMetadataAsync(fileId: String,
                              e2eToken: String?,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, String?, String?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            getE2EEMetadata(fileId: fileId,
                            e2eToken: e2eToken,
                            account: account,
                            options: options,
                            taskHandler: taskHandler) { account, metadata, signature, response, error in
                continuation.resume(returning: (account, metadata, signature, response, error))
            }
        }
    }

    // Uploads E2EE metadata for a specific file on the Nextcloud server, using the specified HTTP method.
    // The request includes the E2E token and optional metadata and signature. The server may return the
    // stored metadata back in the response.
    //
    // Parameters:
    // - fileId: The identifier of the file to update metadata for.
    // - e2eToken: Required token used to authorize the E2EE update.
    // - e2eMetadata: Optional encrypted metadata payload to be stored.
    // - signature: Optional signature for integrity/authentication (added to header).
    // - method: The HTTP method to use (e.g., "PUT", "POST").
    // - account: The Nextcloud account performing the request.
    // - options: Optional request options (includes version, queue, etc.).
    // - taskHandler: Closure to access the URLSessionTask.
    // - completion: Completion handler returning the account, stored metadata (if any), response, and NKError.
    func putE2EEMetadata(fileId: String,
                         e2eToken: String,
                         e2eMetadata: String?,
                         signature: String?,
                         method: String,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ metadata: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/meta-data/\(fileId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: method)
        var parameters: [String: Any] = [:]
        parameters["e2e-token"] = e2eToken
        headers.update(name: "e2e-token", value: e2eToken)
        if let e2eMetadata {
            parameters["metaData"] = e2eMetadata
        }
        if let signature {
            headers.update(name: "X-NC-E2EE-SIGNATURE", value: signature)
        }

        nkSession.sessionData.request(url, method: method, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                return options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let metadata = json["ocs"]["data"]["meta-data"].string
                    options.queue.async { completion(account, metadata, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously uploads E2EE metadata for a file using a given method, token and optional signature.
    /// - Parameters:
    ///   - fileId: The ID of the file to update metadata for.
    ///   - e2eToken: The E2EE token used for authentication.
    ///   - e2eMetadata: Optional encrypted metadata.
    ///   - signature: Optional cryptographic signature (added to header).
    ///   - method: HTTP method to use (e.g., "PUT").
    ///   - account: The account performing the operation.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the session task.
    /// - Returns: A tuple containing the account, stored metadata (if any), response, and NKError.
    func putE2EEMetadataAsync(fileId: String,
                              e2eToken: String,
                              e2eMetadata: String?,
                              signature: String?,
                              method: String,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, String?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            putE2EEMetadata(fileId: fileId,
                            e2eToken: e2eToken,
                            e2eMetadata: e2eMetadata,
                            signature: signature,
                            method: method,
                            account: account,
                            options: options,
                            taskHandler: taskHandler) { account, metadata, response, error in
                continuation.resume(returning: (account, metadata, response, error))
            }
        }
    }

    // MARK: -

    // Retrieves the public E2EE certificate (public key) for the given account or a specified user.
    // If `user` is nil, the certificate for the current account is returned.
    // If `user` is provided, the request fetches the public key of that user using a `users=[...]` query parameter.
    //
    // Parameters:
    // - user: Optional username to fetch the public key for. If nil, fetches the current user's key.
    // - account: The Nextcloud account performing the request.
    // - options: Optional request options (includes version, task description, queue, etc.).
    // - taskHandler: Closure to access the URLSessionTask.
    // - completion: Completion handler returning the account, the certificate string, the certificate user (if applicable), the raw response, and any NKError.
    func getE2EECertificate(user: String? = nil,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ certificate: String?, _ certificateUser: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {

        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        var endpoint = ""
        if let user = user {
            guard let users = ("[\"" + user + "\"]").urlEncoded else {
                return options.queue.async { completion(account, nil, nil, nil, .urlError) }
            }
            endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/public-key?users=" + users
        } else {
            endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/public-key"
        }
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["public-keys"][nkSession.userId].stringValue
                    if let user = user {
                        let keyUser = json["ocs"]["data"]["public-keys"][user].string
                        options.queue.async { completion(account, key, keyUser, response, .success) }
                    } else {
                        options.queue.async { completion(account, key, nil, response, .success) }
                    }
                } else {
                    options.queue.async { completion(account, nil, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves the E2EE public certificate for the current or specified user.
    /// - Parameters:
    ///   - user: Optional username to query (nil fetches current user).
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Closure to access the session task.
    /// - Returns: A tuple with account, current user's certificate, specified user's certificate (if any), response, and NKError.
    func getE2EECertificateAsync(user: String? = nil,
                                 account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, String?, String?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            getE2EECertificate(user: user,
                               account: account,
                               options: options,
                               taskHandler: taskHandler) { account, certificate, certificateUser, response, error in
                continuation.resume(returning: (account, certificate, certificateUser, response, error))
            }
        }
    }

    // Retrieves the private E2EE key for the current account from the Nextcloud server.
    // This key is typically encrypted and used for decrypting user data locally.
    // The endpoint used is versioned via `options.version` (default: "v1").
    //
    // Parameters:
    // - account: The Nextcloud account requesting the private key.
    // - options: Optional request options (includes version, queue, etc.).
    // - taskHandler: Closure to access the URLSessionTask.
    // - completion: Completion handler returning the account, private key string, raw response, and NKError.
    func getE2EEPrivateKey(account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ privateKey: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/private-key"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
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
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["private-key"].stringValue
                    options.queue.async { completion(account, key, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves the private E2EE key for the given account.
    /// - Parameters:
    ///   - account: The account requesting the private key.
    ///   - options: Optional request options.
    ///   - taskHandler: Closure to access the URLSessionTask.
    /// - Returns: A tuple containing the account, private key (if any), response, and NKError.
    func getE2EEPrivateKeyAsync(account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, String?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            getE2EEPrivateKey(account: account,
                              options: options,
                              taskHandler: taskHandler) { account, key, response, error in
                continuation.resume(returning: (account, key, response, error))
            }
        }
    }

    // Retrieves the server's E2EE public key for the current Nextcloud instance.
    // This key is used by clients to encrypt data that will be sent to the server.
    // The request targets the `server-key` endpoint and returns the PEM-formatted public key.
    //
    // Parameters:
    // - account: The Nextcloud account performing the request.
    // - options: Optional request options (includes version, queue, etc.).
    // - taskHandler: Closure to access the URLSessionTask.
    // - completion: Completion handler returning the account, public key string, raw response, and NKError.
    func getE2EEPublicKey(account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          completion: @escaping (_ account: String, _ publicKey: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/server-key"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
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
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["public-key"].stringValue
                    options.queue.async { completion(account, key, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves the server’s E2EE public key for the specified account.
    /// - Parameters:
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Closure to access the session task.
    /// - Returns: A tuple with account, public key (if any), raw response, and NKError.
    func getE2EEPublicKeyAsync(account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, String?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            getE2EEPublicKey(account: account,
                             options: options,
                             taskHandler: taskHandler) { account, key, response, error in
                continuation.resume(returning: (account, key, response, error))
            }
        }
    }

    // Sends a certificate signing request (CSR) to the server in order to obtain a signed E2EE public certificate.
    // The server responds with a signed public key associated with the account.
    // The request is sent via HTTP POST to the `/public-key` endpoint.
    //
    // Parameters:
    // - certificate: The CSR (Certificate Signing Request) in string format to be signed by the server.
    // - account: The Nextcloud account performing the request.
    // - options: Optional request options (e.g., version, queue, headers).
    // - taskHandler: Closure to access the URLSessionTask.
    // - completion: Completion handler returning the account, signed certificate string, response, and NKError.
    func signE2EECertificate(certificate: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ certificate: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/public-key"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters = ["csr": certificate]

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
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["public-key"].stringValue
                    print(key)
                    options.queue.async { completion(account, key, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously requests a signed E2EE public key from the server by submitting a CSR.
    /// - Parameters:
    ///   - certificate: The certificate signing request (CSR) string.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Closure to access the session task.
    /// - Returns: A tuple containing the account, signed public key (if any), response, and NKError.
    func signE2EECertificateAsync(certificate: String,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, String?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            signE2EECertificate(certificate: certificate,
                                account: account,
                                options: options,
                                taskHandler: taskHandler) { account, signedCert, response, error in
                continuation.resume(returning: (account, signedCert, response, error))
            }
        }
    }

    // Stores the user's E2EE private key securely on the Nextcloud server.
    // This is typically done during initial key setup or key backup.
    // The private key is sent as a POST parameter to the `/private-key` endpoint.
    //
    // Parameters:
    // - privateKey: The PEM-formatted private key string to be stored on the server.
    // - account: The Nextcloud account performing the operation.
    // - options: Optional request options (versioning, queue dispatch, headers, etc.).
    // - taskHandler: Closure to access the URLSessionTask.
    // - completion: Completion handler returning the account, stored private key (as echoed back), response, and NKError.
    func storeE2EEPrivateKey(privateKey: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ privateKey: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/private-key"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters = ["privateKey": privateKey]

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
                if 200..<300 ~= statusCode {
                    let key = json["ocs"]["data"]["private-key"].stringValue
                    options.queue.async { completion(account, key, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously stores the given E2EE private key for the specified account.
    /// - Parameters:
    ///   - privateKey: The PEM-formatted private key to store.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Optional request options.
    ///   - taskHandler: Closure to access the session task.
    /// - Returns: A tuple with account, echoed private key (if any), response, and NKError.
    func storeE2EEPrivateKeyAsync(privateKey: String,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, String?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            storeE2EEPrivateKey(privateKey: privateKey,
                                account: account,
                                options: options,
                                taskHandler: taskHandler) { account, key, response, error in
                continuation.resume(returning: (account, key, response, error))
            }
        }
    }

    // Deletes the currently stored E2EE public certificate from the Nextcloud server.
    // This is typically used during key revocation or reinitialization of E2EE.
    // The request targets the `public-key` endpoint with the HTTP DELETE method.
    //
    // Parameters:
    // - account: The Nextcloud account requesting the deletion of the certificate.
    // - options: Optional request options (e.g., version, dispatch queue, headers).
    // - taskHandler: Closure to access the URLSessionTask.
    // - completion: Completion handler returning the account, raw response, and NKError.
    func deleteE2EECertificate(account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                               completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/public-key"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    /// Asynchronously deletes the E2EE public certificate for the given account.
    /// - Parameters:
    ///   - account: The Nextcloud account performing the deletion.
    ///   - options: Optional request options.
    ///   - taskHandler: Closure to access the session task.
    /// - Returns: A tuple containing the account, response, and NKError.
    func deleteE2EECertificateAsync(account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            deleteE2EECertificate(account: account,
                                  options: options,
                                  taskHandler: taskHandler) { account, response, error in
                continuation.resume(returning: (account, response, error))
            }
        }
    }

    // Deletes the user's E2EE private key stored on the Nextcloud server.
    // This operation is typically performed when revoking access to the encrypted data,
    // or during account reset scenarios.
    //
    // Parameters:
    // - account: The Nextcloud account requesting the deletion of its private key.
    // - options: Optional request options (API version, dispatch queue, headers).
    // - taskHandler: Closure to access the URLSessionTask.
    // - completion: Completion handler returning the account, raw response, and NKError.
    func deleteE2EEPrivateKey(account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                              completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        var version = "v1"
        if let optionsVesion = options.version {
            version = optionsVesion
        }
        let endpoint = "ocs/v2.php/apps/end_to_end_encryption/api/\(version)/private-key"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    /// Asynchronously deletes the E2EE private key for the given account.
    /// - Parameters:
    ///   - account: The Nextcloud account performing the deletion.
    ///   - options: Optional request options.
    ///   - taskHandler: Closure to access the session task.
    /// - Returns: A tuple containing the account, response, and NKError.
    func deleteE2EEPrivateKeyAsync(account: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            deleteE2EEPrivateKey(account: account,
                                 options: options,
                                 taskHandler: taskHandler) { account, response, error in
                continuation.resume(returning: (account, response, error))
            }
        }
    }
}
