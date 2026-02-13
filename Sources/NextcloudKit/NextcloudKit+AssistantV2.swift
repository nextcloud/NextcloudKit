// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

public extension NextcloudKit {
    /// Retrieves the list of supported task types for a specific account and task category.
    /// Typically used to discover available AI or text processing capabilities.
    ///
    /// - Parameters:
    ///   - account: The Nextcloud account making the request.
    ///   - supportedTaskType: Type of tasks to retrieve, default is "Text".
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the URLSessionTask.
    /// - Returns: A tuple with named values for account, supported types, response, and error.
    func textProcessingGetTypesV2(account: String,
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
            let endpoint = "ocs/v2.php/taskprocessing/tasktypes"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, types: nil, responseData: nil, error: .urlError))
                }
            }

            nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, types: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    if let result = try? decoder.decode(OCSTaskTypesResponse.self, from: data) {
                        var types = result.ocs.data.types.map { (key, value) -> TaskTypeData in
                            var taskType = value
                            taskType.id = key
                            return taskType
                        }
                        types = types
                            .filter { $0.inputShape?.input?.type == supportedTaskType && $0.outputShape?.output?.type == supportedTaskType }
                            .sorted { ($0.id ?? "") < ($1.id ?? "") }
                        options.queue.async {
                            continuation.resume(returning: (account: account, types: types, responseData: response, error: .success))
                        }
                    } else {
                        options.queue.async {
                            continuation.resume(returning: (account: account, types: nil, responseData: response, error: .success))
                        }
                    }
                }
            }
        }
    }

    /// Schedules a new text processing task for a specific account and task type.
    /// Useful for initiating assistant-based text analysis, generation, or transformation.
    ///
    /// - Parameters:
    ///   - input: The input text to be processed.
    ///   - taskType: The specific task type to execute (e.g., summarization, sentiment analysis).
    ///   - account: The Nextcloud account initiating the task.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, scheduled task, response, and error.
    func textProcessingScheduleV2(input: String,
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
            let endpoint = "/ocs/v2.php/taskprocessing/schedule"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, task: nil, responseData: nil, error: .urlError))
                }
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
                    options.queue.async {
                        continuation.resume(returning: (account: account, task: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode(OCSTaskResponse.self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, task: result?.ocs.data.task, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Retrieves all scheduled text processing tasks of a specific type for the given account.
    /// Useful for listing and tracking tasks like summarization, transcription, or classification.
    ///
    /// - Parameters:
    ///   - taskType: Identifier of the task type to filter tasks (e.g., "Text").
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, task list, response, and error.
    func textProcessingGetTasksV2(taskType: String,
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
            let endpoint = "/ocs/v2.php/taskprocessing/tasks?taskType=\(taskType)"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, tasks: nil, responseData: nil, error: .urlError))
                }
            }

            nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, tasks: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode(OCSTaskListResponse.self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, tasks: result.map { TaskList(tasks: $0.ocs.data.tasks) }, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Deletes a scheduled text processing task with a specific identifier.
    /// Useful for canceling tasks that are no longer needed or invalid.
    ///
    /// - Parameters:
    ///   - taskId: The unique identifier of the task to delete.
    ///   - account: The Nextcloud account executing the deletion.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, response, and error.
    func textProcessingDeleteTaskV2(taskId: Int64,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let endpoint = "/ocs/v2.php/taskprocessing/task/\(taskId)"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, responseData: nil, error: .urlError))
                }
            }

            nkSession.sessionData.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, responseData: response, error: error))
                    }
                case .success:
                    options.queue.async {
                        continuation.resume(returning: (account: account, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Retrieves all chat sessions. Each session has messages.
    ///
    /// - Parameters:
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, sessions, response, and error.
    func getAssistantChatConversations(account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        sessions: [AssistantConversation]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let endpoint = "/ocs/v2.php/apps/assistant/chat/sessions"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, sessions: nil, responseData: nil, error: .urlError))
                }
            }

            nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, sessions: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode([AssistantConversation].self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, sessions: result, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Retrieves all messages for a given chat session.
    ///
    /// - Parameters:
    ///   - sessionId: The chat session from which to fetch all messages.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, chat messages, response, and error.
    func getAssistantChatMessages(sessionId: Int,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        chatMessages: [AssistantChatMessage]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let endpoint = "/ocs/v2.php/apps/assistant/chat/messages"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, chatMessages: nil, responseData: nil, error: .urlError))
                }
            }

            nkSession.sessionData.request(url, method: .get, parameters: ["sessionId": sessionId], encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, chatMessages: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode([AssistantChatMessage].self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, chatMessages: result, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Creates a new message in a chat session.
    ///
    /// - Parameters:
    ///   - messageRequest: The message request containing sessionId, role, content, and timestamp.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, created message, response, and error.
    func createAssistantChatMessage(messageRequest: AssistantChatMessageRequest,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        chatMessage: AssistantChatMessage?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let endpoint = "/ocs/v2.php/apps/assistant/chat/new_message"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, chatMessage: nil, responseData: nil, error: .urlError))
                }
            }

            nkSession.sessionData.request(url, method: .put, parameters: messageRequest.bodyMap, encoding: JSONEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, chatMessage: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode(AssistantChatMessage.self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, chatMessage: result, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Creates a new chat conversation/session.
    ///
    /// - Parameters:
    ///   - title: Optional title for the conversation.
    ///   - timestamp: The timestamp for the conversation creation.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, created conversation, response, and error.
    func createAssistantChatConversation(title: String?,
                                         timestamp: Int,
                                         account: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        conversation: AssistantCreatedConversation?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let endpoint = "/ocs/v2.php/apps/assistant/chat/new_session"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, conversation: nil, responseData: nil, error: .urlError))
                }
            }

            var parameters: [String: Any] = ["timestamp": timestamp]
            if let title = title {
                parameters["title"] = title
            }

            nkSession.sessionData.request(url, method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, conversation: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode(AssistantCreatedConversation.self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, conversation: result, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Checks the generation status of a chat message task.
    ///
    /// - Parameters:
    ///   - taskId: The ID of the generation task to check.
    ///   - sessionId: The chat session ID.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, chat message (if ready), response, and error.
    func checkAssistantChatGeneration(taskId: Int,
                                      sessionId: Int,
                                      account: String,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        chatMessage: AssistantChatMessage?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let endpoint = "/ocs/v2.php/apps/assistant/chat/check_generation"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, chatMessage: nil, responseData: nil, error: .urlError))
                }
            }

            let parameters: [String: Any] = ["taskId": taskId, "sessionId": sessionId]

            nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, chatMessage: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode(AssistantChatMessage.self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, chatMessage: result, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Triggers generation for a chat session.
    ///
    /// - Parameters:
    ///   - sessionId: The chat session ID to generate for.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, session task, response, and error.
    func generateAssistantChatSession(sessionId: Int,
                                      account: String,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        sessionTask: AssistantSessionTask?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let endpoint = "/ocs/v2.php/apps/assistant/chat/generate"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, sessionTask: nil, responseData: nil, error: .urlError))
                }
            }

            let parameters: [String: Any] = ["sessionId": sessionId]

            nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, sessionTask: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode(AssistantSessionTask.self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, sessionTask: result, responseData: response, error: .success))
                    }
                }
            }
        }
    }

    /// Checks if a chat session exists and retrieves its details.
    ///
    /// - Parameters:
    ///   - sessionId: The ID of the chat session to check.
    ///   - account: The Nextcloud account performing the request.
    ///   - options: Optional HTTP request configuration.
    ///   - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - Returns: A tuple with named values for account, session (if found), response, and error.
    func checkAssistantChatSession(sessionId: Int,
                                   account: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        session: AssistantSession?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let endpoint = "/ocs/v2.php/apps/assistant/chat/check_session"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account: account, session: nil, responseData: nil, error: .urlError))
                }
            }

            let parameters: [String: Any] = ["sessionId": sessionId]

            nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, session: nil, responseData: response, error: error))
                    }
                case .success(let data):
                    let decoder = JSONDecoder()
                    let result = try? decoder.decode(AssistantSession.self, from: data)
                    options.queue.async {
                        continuation.resume(returning: (account: account, session: result, responseData: response, error: .success))
                    }
                }
            }
        }
    }
}
