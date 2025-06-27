// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func textProcessingGetTypesV2(account: String,
                                  supportedTaskType: String = "Text",
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ types: [TaskTypeData]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/taskprocessing/tasktypes"
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

    /// Asynchronously retrieves available task types (v2) for the given account and supported task type.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - supportedTaskType: The supported type (e.g. "Text", default: "Text").
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, list of task types (if any), response data, and error.
    func textProcessingGetTypesV2Async(account: String,
                                       supportedTaskType: String = "Text",
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, [TaskTypeData]?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingGetTypesV2(account: account,
                                     supportedTaskType: supportedTaskType,
                                     options: options,
                                     taskHandler: taskHandler) { account, types, responseData, error in
                continuation.resume(returning: (account, types, responseData, error))
            }
        }
    }

    func textProcessingScheduleV2(input: String,
                                  taskType: TaskTypeData,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ task: AssistantTask?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/taskprocessing/schedule"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
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

    /// Asynchronously schedules a text processing task using V2 API.
    /// - Parameters:
    ///   - input: The input text to process.
    ///   - taskType: The task type data (e.g., summarization, translation).
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, scheduled task (if any), response data, and error.
    func textProcessingScheduleV2Async(input: String,
                                       taskType: TaskTypeData,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AssistantTask?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingScheduleV2(input: input,
                                     taskType: taskType,
                                     account: account,
                                     options: options,
                                     taskHandler: taskHandler) { account, task, responseData, error in
                continuation.resume(returning: (account, task, responseData, error))
            }
        }
    }

    func textProcessingGetTasksV2(taskType: String,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ tasks: TaskList?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/taskprocessing/tasks?taskType=\(taskType)"
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
                    let result = TaskList.deserialize(from: data)
                    options.queue.async { completion(account, result, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    /// Asynchronously retrieves the list of tasks for a given task type using V2 API.
    /// - Parameters:
    ///   - taskType: The type of tasks to retrieve (e.g., "summary").
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, list of tasks (if any), response data, and error.
    func textProcessingGetTasksV2Async(taskType: String,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, TaskList?, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingGetTasksV2(taskType: taskType,
                                     account: account,
                                     options: options,
                                     taskHandler: taskHandler) { account, tasks, responseData, error in
                continuation.resume(returning: (account, tasks, responseData, error))
            }
        }
    }

    func textProcessingDeleteTaskV2(taskId: Int64,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                    completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/taskprocessing/task/\(taskId)"
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

    /// Asynchronously deletes a text processing task (V2) by its ID.
    /// - Parameters:
    ///   - taskId: The ID of the task to delete (Int64).
    ///   - account: The account identifier.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with account, response data, and error.
    func textProcessingDeleteTaskV2Async(taskId: Int64,
                                         account: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (String, AFDataResponse<Data>?, NKError) {
        await withCheckedContinuation { continuation in
            textProcessingDeleteTaskV2(taskId: taskId,
                                       account: account,
                                       options: options,
                                       taskHandler: taskHandler) { account, responseData, error in
                continuation.resume(returning: (account, responseData, error))
            }
        }
    }
}


