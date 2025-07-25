// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Retrieves the list of supported task types for a specific account and task category.
    /// Typically used to discover available AI or text processing capabilities.
    ///
    /// Parameters:
    /// - account: The Nextcloud account making the request.
    /// - supportedTaskType: Type of tasks to retrieve, default is "Text".
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the URLSessionTask.
    /// - completion: Completion handler returning the account, list of supported types, raw response, and NKError.
    func textProcessingGetTypesV2(account: String,
                                  supportedTaskType: String = "Text",
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ types: [TaskTypeData]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/taskprocessing/tasktypes"
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
                    let dict = TaskTypes.deserialize(from: data)
                    let result = dict?.types.map({$0})
                    let filteredResult = result?
                        .filter({ $0.inputShape?.input?.type == supportedTaskType && $0.outputShape?.output?.type == supportedTaskType })
                        .sorted(by: {$0.id! < $1.id!})
                    options.queue.async { completion(account, filteredResult, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves the supported task types for the given account and category.
    /// - Parameters:
    ///   - account: Account performing the request.
    ///   - supportedTaskType: The task category to filter by (default: "Text").
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback for the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, supported types, response, and error.
    func textProcessingGetTypesV2Async(account: String,
                                       supportedTaskType: String = "Text",
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        types: [TaskTypeData]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingGetTypesV2(account: account,
                                     supportedTaskType: supportedTaskType,
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

    /// Schedules a new text processing task for a specific account and task type.
    /// Useful for initiating assistant-based text analysis, generation, or transformation.
    ///
    /// Parameters:
    /// - input: The input text to be processed.
    /// - taskType: The specific task type to execute (e.g., summarization, sentiment analysis).
    /// - account: The Nextcloud account initiating the task.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, scheduled task, raw response, and NKError.
    func textProcessingScheduleV2(input: String,
                                  taskType: TaskTypeData,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ task: AssistantTask?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/taskprocessing/schedule"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let inputField: [String: String] = ["input": input]
        let parameters: [String: Any] = ["input": inputField, "type": taskType.id ?? "", "appId": "assistant", "customId": ""]

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
                    let result = AssistantTask.deserialize(from: data)
                    options.queue.async { completion(account, result, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously schedules a new text processing task using the specified task type.
    /// - Parameters:
    ///   - input: Input text to be processed.
    ///   - taskType: Type of task to be executed.
    ///   - account: The account performing the scheduling.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, scheduled task, response, and error.
    func textProcessingScheduleV2Async(input: String,
                                       taskType: TaskTypeData,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        task: AssistantTask?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingScheduleV2(input: input,
                                     taskType: taskType,
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

    /// Retrieves all scheduled text processing tasks of a specific type for the given account.
    /// Useful for listing and tracking tasks like summarization, transcription, or classification.
    ///
    /// Parameters:
    /// - taskType: Identifier of the task type to filter tasks (e.g., "Text").
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, list of tasks, raw response, and NKError.
    func textProcessingGetTasksV2(taskType: String,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ tasks: TaskList?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/taskprocessing/tasks?taskType=\(taskType)"
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
                    let result = TaskList.deserialize(from: data)
                    options.queue.async { completion(account, result, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves a list of scheduled text processing tasks for a specific type.
    /// - Parameters:
    ///   - taskType: Type of the tasks to query.
    ///   - account: The account performing the query.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, task list, response, and error.
    func textProcessingGetTasksV2Async(taskType: String,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        tasks: TaskList?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingGetTasksV2(taskType: taskType,
                                     account: account,
                                     options: options,
                                     taskHandler: taskHandler) { account, tasks, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    tasks: tasks,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Deletes a scheduled text processing task with a specific identifier.
    /// Useful for canceling tasks that are no longer needed or invalid.
    ///
    /// Parameters:
    /// - taskId: The unique identifier of the task to delete.
    /// - account: The Nextcloud account executing the deletion.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, raw response, and NKError.
    func textProcessingDeleteTaskV2(taskId: Int64,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                    completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/taskprocessing/task/\(taskId)"
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

    /// Asynchronously deletes a text processing task by ID for the specified account.
    /// - Parameters:
    ///   - taskId: ID of the task to be deleted.
    ///   - account: The account performing the operation.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, response, and error.
    func textProcessingDeleteTaskV2Async(taskId: Int64,
                                         account: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            textProcessingDeleteTaskV2(taskId: taskId,
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


