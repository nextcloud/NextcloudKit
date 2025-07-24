// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Retrieves the list of supported text processing task types from the server.
    /// These types define the kinds of operations (e.g., summarization, translation) supported by the assistant API.
    ///
    /// Parameters:
    /// - account: The Nextcloud account initiating the request.
    /// - options: Optional configuration for the HTTP request.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler providing the account, available task types, response, and NKError.
    func textProcessingGetTypes(account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ types: [NKTextProcessingTaskType]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/textprocessing/tasktypes"
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

    /// Asynchronously retrieves available text processing task types from the server.
    /// - Parameters:
    ///   - account: The Nextcloud account initiating the request.
    ///   - options: Optional request options.
    ///   - taskHandler: Closure to access the session task.
    /// - Returns: A tuple with named values for account, list of task types, response, and error.
    func textProcessingGetTypesAsync(account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        types: [NKTextProcessingTaskType]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingGetTypes(account: account,
                                   options: options,
                                   taskHandler: taskHandler) { account, types, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    types: types,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Schedules a new text processing task on the server (e.g., translation, summary, etc.).
    /// The request includes the input text, the type of task to execute, and a unique identifier.
    ///
    /// Parameters:
    /// - input: The raw input string to be processed.
    /// - typeId: The identifier of the task type (e.g., "summarize", "translate").
    /// - appId: The application identifier (default is "assistant").
    /// - identifier: A client-side unique string to track this task.
    /// - account: The Nextcloud account executing the request.
    /// - options: Optional request configuration (headers, queue, etc.).
    /// - taskHandler: Optional closure to access the URLSessionTask.
    /// - completion: Completion handler returning the account, resulting task object, response, and any NKError.
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
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

    /// Asynchronously schedules a text processing task on the server.
    /// - Parameters:
    ///   - input: Input string to process.
    ///   - typeId: Task type identifier.
    ///   - appId: Optional app ID, defaults to "assistant".
    ///   - identifier: Unique task identifier.
    ///   - account: Nextcloud account.
    ///   - options: Request configuration.
    ///   - taskHandler: Optional access to the URLSessionTask.
    /// - Returns: A tuple with named values for account, task object, raw response, and error.
    func textProcessingScheduleAsync(input: String,
                                     typeId: String,
                                     appId: String = "assistant",
                                     identifier: String,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        task: NKTextProcessingTask?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingSchedule(input: input,
                                   typeId: typeId,
                                   appId: appId,
                                   identifier: identifier,
                                   account: account,
                                   options: options,
                                   taskHandler: taskHandler) { account, task, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    task: task,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Retrieves the current status and data of a previously scheduled text processing task.
    /// Useful for polling or checking the result of a long-running task by its unique ID.
    ///
    /// Parameters:
    /// - taskId: The server-side ID of the text processing task to retrieve.
    /// - account: The Nextcloud account making the request.
    /// - options: Optional request configuration.
    /// - taskHandler: Optional closure to access the URLSessionTask.
    /// - completion: Completion handler returning the account, task object, raw response, and NKError.
    func textProcessingGetTask(taskId: Int,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                               completion: @escaping (_ account: String, _ task: NKTextProcessingTask?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/textprocessing/task/\(taskId)"
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

    /// Asynchronously retrieves the details of a specific text processing task.
    /// - Parameters:
    ///   - taskId: The ID of the task to fetch.
    ///   - account: The account used for the request.
    ///   - options: Optional configuration.
    ///   - taskHandler: Closure to access the session task.
    /// - Returns: A tuple with named values for account, task object, response, and error.
    func textProcessingGetTaskAsync(taskId: Int,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        task: NKTextProcessingTask?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingGetTask(taskId: taskId,
                                  account: account,
                                  options: options,
                                  taskHandler: taskHandler) { account, task, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    task: task,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Deletes a specific text processing task on the server.
    /// This is used to cancel or clean up tasks that are no longer needed.
    ///
    /// Parameters:
    /// - taskId: The ID of the task to be deleted.
    /// - account: The Nextcloud account making the request.
    /// - options: Optional request configuration.
    /// - taskHandler: Optional closure to access the URLSessionTask.
    /// - completion: Completion handler returning the account, deleted task object, raw response, and NKError.
    func textProcessingDeleteTask(taskId: Int,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ task: NKTextProcessingTask?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/textprocessing/task/\(taskId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
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

    /// Asynchronously deletes a scheduled text processing task from the server.
    /// - Parameters:
    ///   - taskId: ID of the task to delete.
    ///   - account: Account executing the deletion.
    ///   - options: Request options.
    ///   - taskHandler: Callback for the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, deleted task object, response, and error.
    func textProcessingDeleteTaskAsync(taskId: Int,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        task: NKTextProcessingTask?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingDeleteTask(taskId: taskId,
                                     account: account,
                                     options: options,
                                     taskHandler: taskHandler) { account, task, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    task: task,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Retrieves a list of all text processing tasks associated with a specific app ID.
    /// This includes both pending and completed tasks, useful for tracking the assistant's activity.
    ///
    /// Parameters:
    /// - appId: Identifier of the application requesting the tasks (e.g., "assistant").
    /// - account: The Nextcloud account making the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the URLSessionTask.
    /// - completion: Completion handler returning the account, task list, raw response, and NKError.
    func textProcessingTaskList(appId: String,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ task: [NKTextProcessingTask]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/textprocessing/tasks/app/\(appId)"
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

    /// Asynchronously retrieves all text processing tasks associated with a specific app ID.
    /// - Parameters:
    ///   - appId: The application identifier to filter the task list.
    ///   - account: The account performing the request.
    ///   - options: Optional request configuration.
    ///   - taskHandler: Callback for the URLSessionTask.
    /// - Returns: A tuple with named values for account, task list, response, and error.
    func textProcessingTaskListAsync(appId: String,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        task: [NKTextProcessingTask]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingTaskList(appId: appId,
                                   account: account,
                                   options: options,
                                   taskHandler: taskHandler) { account, task, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    task: task,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }
}
