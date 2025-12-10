// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    // MARK: - App Password

    /// Retrieves an app password (token) for the given user credentials and server URL.
    ///
    /// Parameters:
    /// - url: The base server URL (e.g., https://cloud.example.com).
    /// - user: The username for authentication.
    /// - password: The user's password.
    /// - userAgent: Optional user-agent string to include in the request.
    /// - options: Optional request configuration (headers, queue, etc.).
    /// - taskHandler: Callback for observing the underlying URLSessionTask.
    /// - completion: Returns the token string (if any), raw response data, and NKError result.
    internal func sendRequest(account: String,
                     fileId: String,
                     filePath: String,
                     url: String,
                     method: String,
                     params: [String: String]? = nil,
                     options: NKRequestOptions = NKRequestOptions(),
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ token: String?, _ uiResponse: NKClientIntegrationUIResponse?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {

//        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
//              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
//            return completion(nil, nil, .urlError)
//        }
//
//        let httpMethod = HTTPMethod(rawValue: method.uppercased())
//
//        //        var queryParams: [String: Any] = [:]
//        typealias pEnum = NKDeclarativeUICapabilities.Params
//        // Build query params if provided
//        var queryParams: [String: Any]? = nil
//        if let params = params {
//            var qp: [String: Any] = [:]
//            for (key, value) in params {
//                switch key {
//                case NKDeclarativeUICapabilities.Params.fileId.rawValue:
//                    qp[key] = fileId
//                case NKDeclarativeUICapabilities.Params.filePath.rawValue:
//                    qp[key] = filePath
//                default:
//                    qp[key] = value
//                }
//            }
//            queryParams = qp
//        }
//
//
//        guard let url = URL(string: nkSession.urlBase + url) else {
//            return options.queue.async { completion(nil, nil, .urlError) }
//        }
//
//        //            var headers: HTTPHeaders = [.init(name: "OCS-APIRequest", value: "true")]
//        //            headers.update(.userAgent(nkSession.userAgent))
//
//
////        let encoding: ParameterEncoding = (httpMethod == .get ? URLEncoding.default : JSONEncoding.default)
//
//        unauthorizedSession.request(url,
//                                    method: httpMethod,
//                                    parameters: queryParams,
//                                    encoding: URLEncoding.queryString,
//                                    headers: headers)
//        .validate(statusCode: 200..<300)
//        .onURLSessionTaskCreation { task in
//            task.taskDescription = options.taskDescription
//            taskHandler(task)
//        }
//        .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
//            switch response.result {
//            case .failure(let error):
//                let error = NKError(error: error, afResponse: response, responseData: response.data)
//                options.queue.async { completion(nil, response, error) }
//            case .success(let data):
//                let apppassword = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataAppPassword(data: data)
//                options.queue.async { completion(apppassword, response, .success) }
//            }
//        }
    }

    /// Asynchronously fetches an app password for the provided user credentials.
    ///
    /// - Parameters:
    ///   - url: The base URL of the Nextcloud server.
    ///   - user: The user login name.
    ///   - password: The user’s password.
    ///   - userAgent: Optional custom user agent for the request.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Callback to observe the task, if needed.
    /// - Returns: A tuple containing the token, response data, and error result.
    func sendRequestAsync(account: String,
                          fileId: String,
                          filePath: String,
                          url: String,
                          method: String,
                          params: [String: String]? = nil,
                          options: NKRequestOptions = NKRequestOptions(),
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        uiResponse: NKClientIntegrationUIResponse?,
        error: NKError
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (account, nil, NKError.urlError)
        }

        let httpMethod = HTTPMethod(rawValue: method.uppercased())

        var queryParams: [String: Any]? = nil
        if let params = params {
            var qp: [String: Any] = [:]
            for (key, value) in params {
                switch key {
                case NKClientIntegration.Params.fileId.rawValue:
                    qp[key] = fileId
                case NKClientIntegration.Params.filePath.rawValue:
                    qp[key] = filePath
                default:
                    qp[key] = value
                }
            }
            queryParams = qp
        }

        let fullURLString = nkSession.urlBase + url
        let finalURLString = fullURLString.replacingOccurrences(of: "{\(NKClientIntegration.Params.fileId.rawValue)}", with: fileId)
            .replacingOccurrences(of: "{\(NKClientIntegration.Params.filePath.rawValue)}", with: filePath)

        guard let finalURL = URL(string: finalURLString) else {
            return (account, nil, NKError.urlError)
        }

        let taskDescription = options.taskDescription

        let request = unauthorizedSession.request(finalURL,
                                                  method: httpMethod,
                                                  parameters: queryParams,
                                                  encoding: URLEncoding.queryString,
                                                  headers: headers)
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { [taskDescription] task in
                task.taskDescription = taskDescription
                taskHandler(task)
            }

        let response = await request.serializingData().response

        switch response.result {
        case .failure(let afError):
            let nkErr = NKError(error: afError, afResponse: response, responseData: response.data)
            return (account, nil, nkErr)
        case .success(let data):
            do {
                let decoder = JSONDecoder()
                let ui = try decoder.decode(NKClientIntegrationUIResponse.self, from: data)
                return (account, ui, .success)
            } catch {
                nkLog(debug: "Client Integration response decoding failed: \(error)")
                return (account, nil, .invalidData)
            }
        }
    }
}

