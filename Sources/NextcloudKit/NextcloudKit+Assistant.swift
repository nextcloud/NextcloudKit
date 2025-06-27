// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func textProcessingGetTypes(account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ types: [NKTextProcessingTaskType]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/textprocessing/tasktypes"
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
                let data = json["ocs"]["data"]["types"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NKTextProcessingTaskType.deserialize(multipleObjects: data)
                    options.queue.async { completion(account, results, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves available text processing task types for the given account.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the `URLSessionTask`.
    /// - Returns: A tuple with account, list of task types, response data, and error.
    func textProcessingGetTypesAsync(account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, [NKTextProcessingTaskType]?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingGetTypes(account: account,
                                   options: options,
                                   taskHandler: taskHandler) { account, types, responseData, error in
                continuation.resume(returning: (account, types, responseData, error))
            }
        }
    }

    func textProcessingSchedule(input: String,
                                typeId: String,
                                appId: String = "assistant",
                                identifier: String,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ task: NKTextProcessingTask?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/textprocessing/schedule"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let parameters: [String: Any] = ["input": input, "type": typeId, "appId": appId, "identifier": identifier]

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
                let data = json["ocs"]["data"]["task"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let result = NKTextProcessingTask.deserialize(singleObject: data)
                    options.queue.async { completion(account, result, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously schedules a text processing task.
    /// - Parameters:
    ///   - input: The input string to be processed.
    ///   - typeId: The identifier of the processing type.
    ///   - appId: The app identifier (default: "assistant").
    ///   - identifier: The task identifier.
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, the scheduled task, response data, and error.
    func textProcessingScheduleAsync(input: String,
                                     typeId: String,
                                     appId: String = "assistant",
                                     identifier: String,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, NKTextProcessingTask?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingSchedule(input: input,
                                   typeId: typeId,
                                   appId: appId,
                                   identifier: identifier,
                                   account: account,
                                   options: options,
                                   taskHandler: taskHandler) { account, task, responseData, error in
                continuation.resume(returning: (account, task, responseData, error))
            }
        }
    }

    func textProcessingGetTask(taskId: Int,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                               completion: @escaping (_ account: String, _ task: NKTextProcessingTask?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/textprocessing/task/\(taskId)"
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
                let data = json["ocs"]["data"]["task"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let result = NKTextProcessingTask.deserialize(singleObject: data)
                    options.queue.async { completion(account, result, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves a specific text processing task by ID.
    /// - Parameters:
    ///   - taskId: The unique identifier of the text processing task.
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, the task (if found), response data, and error.
    func textProcessingGetTaskAsync(taskId: Int,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, NKTextProcessingTask?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingGetTask(taskId: taskId,
                                  account: account,
                                  options: options,
                                  taskHandler: taskHandler) { account, task, responseData, error in
                continuation.resume(returning: (account, task, responseData, error))
            }
        }
    }

    func textProcessingDeleteTask(taskId: Int,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ task: NKTextProcessingTask?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/textprocessing/task/\(taskId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]["task"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let result = NKTextProcessingTask.deserialize(singleObject: data)
                    options.queue.async { completion(account, result, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously deletes a text processing task by its ID.
    /// - Parameters:
    ///   - taskId: The ID of the task to delete.
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, the deleted task (if returned), response data, and error.
    func textProcessingDeleteTaskAsync(taskId: Int,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, NKTextProcessingTask?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingDeleteTask(taskId: taskId,
                                     account: account,
                                     options: options,
                                     taskHandler: taskHandler) { account, task, responseData, error in
                continuation.resume(returning: (account, task, responseData, error))
            }
        }
    }

    func textProcessingTaskList(appId: String,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ task: [NKTextProcessingTask]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/textprocessing/tasks/app/\(appId)"
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
                let data = json["ocs"]["data"]["tasks"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NKTextProcessingTask.deserialize(multipleObjects: data)
                    options.queue.async { completion(account, results, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves the list of text processing tasks for the given app and account.
    /// - Parameters:
    ///   - appId: The application identifier (e.g., "assistant").
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, task list (if any), response data, and error.
    func textProcessingTaskListAsync(appId: String,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, [NKTextProcessingTask]?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingTaskList(appId: appId,
                                   account: account,
                                   options: options,
                                   taskHandler: taskHandler) { account, taskList, responseData, error in
                continuation.resume(returning: (account, taskList, responseData, error))
            }
        }
    }
}


