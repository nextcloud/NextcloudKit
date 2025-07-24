// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

public extension NextcloudKit {
    /// Associates a Live Photo video file with a photo on the server.
    ///
    /// Parameters:
    /// - serverUrlfileNamePath: The full server path to the original photo.
    /// - livePhotoFile: The local path to the Live Photo video file (.mov).
    /// - account: The account performing the operation.
    /// - options: Optional request configuration (e.g., headers, queue, version).
    /// - taskHandler: Callback for tracking the underlying URLSessionTask.
    /// - completion: Returns the account, raw response data, and NKError result.
    func setLivephoto(serverUrlfileNamePath: String,
                      livePhotoFile: String,
                      account: String,
                      options: NKRequestOptions = NKRequestOptions(),
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        guard let url = serverUrlfileNamePath.encodedToUrl,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        let method = HTTPMethod(rawValue: "PROPPATCH")
        guard let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml") else {
            return options.queue.async { completion(account, nil, .urlError) }
        }
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyLivephoto, livePhotoFile)
            urlRequest.httpBody = parameters.data(using: .utf8)
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

    /// Asynchronously attaches a Live Photo video file to an existing image on the server.
    ///
    /// - Parameters:
    ///   - serverUrlfileNamePath: The full server-side path of the target image.
    ///   - livePhotoFile: Local file path of the Live Photo (.mov).
    ///   - account: The Nextcloud account to use for the request.
    ///   - options: Optional request context and headers.
    ///   - taskHandler: Optional callback to observe the URLSessionTask.
    /// - Returns: A tuple with the account, response data, and NKError result.
    func setLivephotoAsync(serverUrlfileNamePath: String,
                           livePhotoFile: String,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath,
                         livePhotoFile: livePhotoFile,
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
