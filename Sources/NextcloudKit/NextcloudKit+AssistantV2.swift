// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

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
                    options.queue.async { completion(account, types, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, .success) }
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
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode(OCSTaskResponse.self, from: data)

                options.queue.async { completion(account, result?.ocs.data.task, response, .success) }
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
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode(OCSTaskListResponse.self, from: data)

                options.queue.async { completion(account, result.map { TaskList(tasks: $0.ocs.data.tasks) }, response, .success) }
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
            case .success:
                options.queue.async { completion(account, response, .success) }
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

    /// Retrieves all chat sessions. Each session has messages.
    ///
    /// Parameters:
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, list of tasks, raw response, and NKError.
    func             getAssistantChatConversations(account: String,
                                                   options: NKRequestOptions = NKRequestOptions(),
                                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                                   completion: @escaping (_ account: String, _ sessions: [AssistantConversation]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/apps/assistant/chat/sessions"
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
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode([AssistantConversation].self, from: data)

                options.queue.async { completion(account, result, response, .success) }
            }
        }
    }

    /// Asynchronously retrieves all chat sessions. Each session has messages.
    ///
    /// - Parameters:
    ///   - account: The account performing the query.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, task list, response, and error.
    func getAssistantChatConversationsAsync(account: String,
                                            options: NKRequestOptions = NKRequestOptions(),
                                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        sessions: [AssistantConversation]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getAssistantChatConversations(
                account: account,
                options: options,
                taskHandler: taskHandler) { account, sessions, responseData, error in
                    continuation.resume(returning: (
                        account: account,
                        sessions: sessions,
                        responseData: responseData,
                        error: error
                    ))
                }
        }
    }

    /// Retrieves all messages for a given chat session.
    ///
    /// Parameters:
    /// - sessionId: The chat session from which to fetch all messages.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, list of tasks, raw response, and NKError.
    func getAssistantChatMessages(sessionId: Int,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ chatMessages: [ChatMessage]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/apps/assistant/chat/messages"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, parameters: ["sessionId": sessionId], encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode([ChatMessage].self, from: data)

                options.queue.async { completion(account, result, response, .success) }
            }
        }
    }

    /// Asynchronously retrieves all messages for a given chat session.
    ///
    /// - Parameters:
    ///   - sessionId: The chat session from which to fetch all messages.
    ///   - account: The account performing the query.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, sessions, response, and error.
    func getAssistantChatMessagesAsync(sessionId: Int,
                                       account: String,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        chatMessage: [ChatMessage]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getAssistantChatMessages(sessionId: sessionId,
                                     account: account,
                                     options: options,
                                     taskHandler: taskHandler) { account, chatMessage, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    chatMessage: chatMessage,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Creates a new message in a chat session.
    ///
    /// Parameters:
    /// - messageRequest: The message request containing sessionId, role, content, and timestamp.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, created message, raw response, and NKError.
    func createAssistantChatMessage(messageRequest: ChatMessageRequest,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                    completion: @escaping (_ account: String, _ chatMessage: ChatMessage?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/apps/assistant/chat/new_message"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .put, parameters: messageRequest.bodyMap, encoding: JSONEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode(ChatMessage.self, from: data)

                options.queue.async { completion(account, result, response, .success) }
            }
        }
    }

    /// Asynchronously creates a new message in a chat session.
    ///
    /// - Parameters:
    ///   - messageRequest: The message request containing sessionId, role, content, and timestamp.
    ///   - account: The account performing the request.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, created message, response, and error.
    func createAssistantChatMessageAsync(messageRequest: ChatMessageRequest,
                                         account: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        chatMessage: ChatMessage?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            createAssistantChatMessage(messageRequest: messageRequest,
                                       account: account,
                                       options: options,
                                       taskHandler: taskHandler) { account, chatMessage, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    chatMessage: chatMessage,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Creates a new chat conversation/session.
    ///
    /// Parameters:
    /// - title: Optional title for the conversation.
    /// - timestamp: The timestamp for the conversation creation.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, created conversation, raw response, and NKError.
    func createAssistantChatConversation(title: String?,
                                    timestamp: Int,
                                    account: String,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                    completion: @escaping (_ account: String, _ conversation: CreateConversation?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/apps/assistant/chat/new_session"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
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
                options.queue.async { completion(account, nil, response, error) }
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode(CreateConversation.self, from: data)

                options.queue.async { completion(account, result, response, .success) }
            }
        }
    }

    /// Asynchronously creates a new chat conversation/session.
    ///
    /// - Parameters:
    ///   - title: Optional title for the conversation.
    ///   - timestamp: The timestamp for the conversation creation.
    ///   - account: The account performing the request.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, created conversation, response, and error.
    func createAssistantChatConversationAsync(title: String?,
                                         timestamp: Int,
                                         account: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        conversation: CreateConversation?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            createAssistantChatConversation(title: title,
                                       timestamp: timestamp,
                                       account: account,
                                       options: options,
                                       taskHandler: taskHandler) { account, conversation, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    conversation: conversation,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Checks the generation status of a chat message task.
    ///
    /// Parameters:
    /// - taskId: The ID of the generation task to check.
    /// - sessionId: The chat session ID.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, chat message (if ready), raw response, and NKError.
    func checkAssistantChatGeneration(taskId: Int,
                                      sessionId: Int,
                                      account: String,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                      completion: @escaping (_ account: String, _ chatMessage: ChatMessage?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/apps/assistant/chat/check_generation"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let parameters: [String: Any] = ["taskId": taskId, "sessionId": sessionId]

        nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode(ChatMessage.self, from: data)

                options.queue.async { completion(account, result, response, .success) }
            }
        }
    }

    /// Asynchronously checks the generation status of a chat message task.
    ///
    /// - Parameters:
    ///   - taskId: The ID of the generation task to check.
    ///   - sessionId: The chat session ID.
    ///   - account: The account performing the request.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, chat message (if ready), response, and error.
    func checkAssistantChatGenerationAsync(taskId: Int,
                                           sessionId: Int,
                                           account: String,
                                           options: NKRequestOptions = NKRequestOptions(),
                                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        chatMessage: ChatMessage?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            checkAssistantChatGeneration(taskId: taskId,
                                         sessionId: sessionId,
                                         account: account,
                                         options: options,
                                         taskHandler: taskHandler) { account, chatMessage, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    chatMessage: chatMessage,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Triggers generation for a chat session.
    ///
    /// Parameters:
    /// - sessionId: The chat session ID to generate for.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, session task, raw response, and NKError.
    func generateAssistantChatSession(sessionId: Int,
                                      account: String,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                      completion: @escaping (_ account: String, _ sessionTask: SessionTask?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/apps/assistant/chat/generate"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let parameters: [String: Any] = ["sessionId": sessionId]

        nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode(SessionTask.self, from: data)

                options.queue.async { completion(account, result, response, .success) }
            }
        }
    }

    /// Asynchronously triggers generation for a chat session.
    ///
    /// - Parameters:
    ///   - sessionId: The chat session ID to generate for.
    ///   - account: The account performing the request.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, session task, response, and error.
    func generateAssistantChatSessionAsync(sessionId: Int,
                                           account: String,
                                           options: NKRequestOptions = NKRequestOptions(),
                                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        sessionTask: SessionTask?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            generateAssistantChatSession(sessionId: sessionId,
                                         account: account,
                                         options: options,
                                         taskHandler: taskHandler) { account, sessionTask, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    sessionTask: sessionTask,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Checks if a chat session exists and retrieves its details.
    ///
    /// Parameters:
    /// - sessionId: The ID of the chat session to check.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional HTTP request configuration.
    /// - taskHandler: Optional closure to access the underlying URLSessionTask.
    /// - completion: Completion handler returning the account, session (if found), raw response, and NKError.
    func checkAssistantChatSession(sessionId: Int,
                                   account: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                   completion: @escaping (_ account: String, _ session: AssistantConversation?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "/ocs/v2.php/apps/assistant/chat/check_session"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let parameters: [String: Any] = ["sessionId": sessionId]

        nkSession.sessionData.request(url, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let data):
                let decoder = JSONDecoder()
                let result = try? decoder.decode(AssistantConversation.self, from: data)

                options.queue.async { completion(account, result, response, .success) }
            }
        }
    }

    /// Asynchronously checks if a chat session exists and retrieves its details.
    ///
    /// - Parameters:
    ///   - sessionId: The ID of the chat session to check.
    ///   - account: The account performing the request.
    ///   - options: Optional configuration.
    ///   - taskHandler: Callback to access the associated URLSessionTask.
    /// - Returns: A tuple with named values for account, session (if found), response, and error.
    func checkAssistantChatSessionAsync(sessionId: Int,
                                        account: String,
                                        options: NKRequestOptions = NKRequestOptions(),
                                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        session: AssistantConversation?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            checkAssistantChatSession(sessionId: sessionId,
                                      account: account,
                                      options: options,
                                      taskHandler: taskHandler) { account, session, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    session: session,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

}
