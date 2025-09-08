// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Subscribes the current device to push notifications.
    ///
    /// Parameters:
    /// - serverUrl: The base server URL for the Nextcloud instance.
    /// - pushTokenHash: Hashed device push token, used for identification.
    /// - devicePublicKey: The public key of the device for encryption/authentication.
    /// - proxyServerUrl: The URL of the proxy push server.
    /// - account: The Nextcloud account performing the subscription.
    /// - options: Optional request configuration (headers, version, etc.).
    /// - taskHandler: Callback to monitor the `URLSessionTask`.
    /// - completion: Returns the account, device identifier, push signature, public key, response data, and NKError.
    func subscribingPushNotification(serverUrl: String,
                                     pushTokenHash: String,
                                     devicePublicKey: String,
                                     proxyServerUrl: String,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                     completion: @escaping (_ account: String, _ deviceIdentifier: String?, _ signature: String?, _ publicKey: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/push"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, nil, nil, .urlError) }
        }
        let parameters = [
            "pushTokenHash": pushTokenHash,
            "devicePublicKey": devicePublicKey,
            "proxyServer": proxyServerUrl
        ]

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let deviceIdentifier = json["ocs"]["data"]["deviceIdentifier"].stringValue
                    let signature = json["ocs"]["data"]["signature"].stringValue
                    let publicKey = json["ocs"]["data"]["publicKey"].stringValue
                    options.queue.async { completion(account, deviceIdentifier, signature, publicKey, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, nil, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously subscribes a device to push notifications on the server.
    ///
    /// - Parameters:
    ///   - serverUrl: Base URL of the Nextcloud server.
    ///   - pushTokenHash: Hashed representation of the device push token.
    ///   - devicePublicKey: Public key for the device used for secure messaging.
    ///   - proxyServerUrl: URL to the push proxy server.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Request customization (e.g., queue, headers).
    ///   - taskHandler: Optional URLSession task observer.
    /// - Returns: A tuple containing the account, device identifier, signature, public key, response data, and NKError.
    func subscribingPushNotificationAsync(serverUrl: String,
                                          pushTokenHash: String,
                                          devicePublicKey: String,
                                          proxyServerUrl: String,
                                          account: String,
                                          options: NKRequestOptions = NKRequestOptions(),
                                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        deviceIdentifier: String?,
        signature: String?,
        publicKey: String?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            subscribingPushNotification(serverUrl: serverUrl,
                                        pushTokenHash: pushTokenHash,
                                        devicePublicKey: devicePublicKey,
                                        proxyServerUrl: proxyServerUrl,
                                        account: account,
                                        options: options,
                                        taskHandler: taskHandler) { account, deviceIdentifier, signature, publicKey, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    deviceIdentifier: deviceIdentifier,
                    signature: signature,
                    publicKey: publicKey,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Unsubscribes the current device from push notifications.
    ///
    /// Parameters:
    /// - serverUrl: The base server URL of the Nextcloud instance.
    /// - account: The Nextcloud account performing the unsubscription.
    /// - options: Optional request configuration (headers, queue, etc.).
    /// - taskHandler: Callback to monitor the `URLSessionTask`.
    /// - completion: Returns the account, raw response data, and NKError.
    func unsubscribingPushNotification(serverUrl: String,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                       completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/notifications/api/v2/push"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

    /// Asynchronously unsubscribes a device from push notifications.
    ///
    /// - Parameters:
    ///   - serverUrl: Base URL of the Nextcloud server.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Request customization (e.g., headers, queue, version).
    ///   - taskHandler: Optional observer for the underlying `URLSessionTask`.
    /// - Returns: A tuple containing the account, response data, and NKError.
    func unsubscribingPushNotificationAsync(serverUrl: String,
                                            account: String,
                                            options: NKRequestOptions = NKRequestOptions(),
                                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            unsubscribingPushNotification(serverUrl: serverUrl,
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

    /// Subscribes a device to the push proxy server for receiving push notifications.
    ///
    /// Parameters:
    /// - proxyServerUrl: The URL of the push proxy server.
    /// - pushToken: The token representing the push notification subscription.
    /// - deviceIdentifier: A unique identifier for the device.
    /// - signature: A signature to validate the subscription.
    /// - publicKey: The public key associated with the device.
    /// - account: The Nextcloud account performing the subscription.
    /// - options: Optional request customization.
    /// - taskHandler: Callback for tracking the underlying URLSessionTask.
    /// - completion: Returns the account, raw response data, and NKError.
    func subscribingPushProxy(proxyServerUrl: String,
                              pushToken: String,
                              deviceIdentifier: String,
                              signature: String,
                              publicKey: String,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                              completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "devices?format=json"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = self.nkCommonInstance.createStandardUrl(serverUrl: proxyServerUrl, endpoint: endpoint),
              let userAgent = options.customUserAgent else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let parameters = [
            "pushToken": pushToken,
            "deviceIdentifier": deviceIdentifier,
            "deviceIdentifierSignature": signature,
            "userPublicKey": publicKey
        ]
        let headers = HTTPHeaders(arrayLiteral: .userAgent(userAgent))

        nkSession.sessionData.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    /// Asynchronously subscribes a device to the push proxy for push notifications.
    ///
    /// - Parameters:
    ///   - proxyServerUrl: URL of the push proxy server.
    ///   - pushToken: Token representing the device's push subscription.
    ///   - deviceIdentifier: Unique identifier for the device.
    ///   - signature: Digital signature for verification.
    ///   - publicKey: Public key associated with the subscription.
    ///   - account: The Nextcloud account performing the operation.
    ///   - options: Request customization (headers, queue, etc.).
    ///   - taskHandler: Callback for monitoring the URLSessionTask.
    /// - Returns: A tuple containing the account, response data, and NKError.
    func subscribingPushProxyAsync(proxyServerUrl: String,
                                    pushToken: String,
                                    deviceIdentifier: String,
                                    signature: String,
                                    publicKey: String,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            subscribingPushProxy(proxyServerUrl: proxyServerUrl,
                                 pushToken: pushToken,
                                 deviceIdentifier: deviceIdentifier,
                                 signature: signature,
                                 publicKey: publicKey,
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

    /// Unsubscribes a device from the push proxy server.
    ///
    /// Parameters:
    /// - proxyServerUrl: The URL of the push proxy server.
    /// - deviceIdentifier: A unique identifier for the device.
    /// - signature: A cryptographic signature to authenticate the request.
    /// - publicKey: The public key associated with the device.
    /// - account: The Nextcloud account initiating the request.
    /// - options: Optional configuration for the request (queue, headers, version, etc.).
    /// - taskHandler: Callback triggered when the underlying URLSessionTask is created.
    /// - completion: Completion handler with account, response data, and NKError result.
    func unsubscribingPushProxy(proxyServerUrl: String,
                                deviceIdentifier: String,
                                signature: String,
                                publicKey: String,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "devices"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = self.nkCommonInstance.createStandardUrl(serverUrl: proxyServerUrl, endpoint: endpoint),
              let userAgent = options.customUserAgent else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let parameters = [
            "deviceIdentifier": deviceIdentifier,
            "deviceIdentifierSignature": signature,
            "userPublicKey": publicKey
        ]
        let headers = HTTPHeaders(arrayLiteral: .userAgent(userAgent))

        nkSession.sessionData.request(url, method: .delete, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
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

    /// Asynchronously unsubscribes a device from the push proxy server.
    ///
    /// - Parameters:
    ///   - proxyServerUrl: The URL of the push proxy server.
    ///   - deviceIdentifier: A unique identifier for the device.
    ///   - signature: A cryptographic signature for validation.
    ///   - publicKey: Public key used for authentication.
    ///   - account: The Nextcloud account performing the unsubscription.
    ///   - options: Optional configuration for headers, queue, etc.
    ///   - taskHandler: Optional callback for monitoring the URLSessionTask.
    /// - Returns: A tuple with the account, the raw AF response data, and an NKError result.
    func unsubscribingPushProxyAsync(proxyServerUrl: String,
                                     deviceIdentifier: String,
                                     signature: String,
                                     publicKey: String,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            unsubscribingPushProxy(proxyServerUrl: proxyServerUrl,
                                   deviceIdentifier: deviceIdentifier,
                                   signature: signature,
                                   publicKey: publicKey,
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
