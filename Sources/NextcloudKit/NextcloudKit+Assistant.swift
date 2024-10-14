//
// SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func textProcessingGetTypes(account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ types: [NKTextProcessingTaskType]?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "ocs/v2.php/textprocessing/tasktypes"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]["types"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NKTextProcessingTaskType.factory(data: data)
                    options.queue.async { completion(account, results, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
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
                                completion: @escaping (_ account: String, _ task: NKTextProcessingTask?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "/ocs/v2.php/textprocessing/schedule"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)
        let parameters: [String: Any] = ["input": input, "type": typeId, "appId": appId, "identifier": identifier]

        sessionManager.request(url, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]["task"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let result = NKTextProcessingTask.factory(data: data)
                    options.queue.async { completion(account, result, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func textProcessingGetTask(taskId: Int,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                               completion: @escaping (_ account: String, _ task: NKTextProcessingTask?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "/ocs/v2.php/textprocessing/task/\(taskId)"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]["task"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let result = NKTextProcessingTask.factory(data: data)
                    options.queue.async { completion(account, result, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func textProcessingDeleteTask(taskId: Int,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                  completion: @escaping (_ account: String, _ task: NKTextProcessingTask?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "/ocs/v2.php/textprocessing/task/\(taskId)"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .delete, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]["task"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let result = NKTextProcessingTask.factory(data: data)
                    options.queue.async { completion(account, result, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }

    func textProcessingTaskList(appId: String,
                                account: String,
                                options: NKRequestOptions = NKRequestOptions(),
                                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                completion: @escaping (_ account: String, _ task: [NKTextProcessingTask]?, _ data: Data?, _ error: NKError) -> Void) {
        let urlBase = self.nkCommonInstance.urlBase
        let endpoint = "/ocs/v2.php/textprocessing/tasks/app/\(appId)"
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]["tasks"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NKTextProcessingTask.factories(data: data)
                    options.queue.async { completion(account, results, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
}

public class NKTextProcessingTaskType {
    public var id: String?
    public var name: String?
    public var description: String?

    public init(id: String? = nil, name: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }

    public init?(json: JSON) {
        self.id = json["id"].string
        self.name = json["name"].string
        self.description = json["description"].string
    }

    static func factory(data: JSON) -> [NKTextProcessingTaskType]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NKTextProcessingTaskType.init)
    }
}

public class NKTextProcessingTask {
    public var id: Int?
    public var type: String?
    public var status: Int?
    public var userId: String?
    public var appId: String?
    public var input: String?
    public var output: String?
    public var identifier: String?
    public var completionExpectedAt: Double?

    public init(id: Int? = nil, type: String? = nil, status: Int? = nil, userId: String? = nil, appId: String? = nil, input: String? = nil, output: String? = nil, identifier: String? = nil, completionExpectedAt: Double? = nil) {
        self.id = id
        self.type = type
        self.status = status
        self.userId = userId
        self.appId = appId
        self.input = input
        self.output = output
        self.identifier = identifier
        self.completionExpectedAt = completionExpectedAt
    }

    public init?(json: JSON) {
        self.id = json["id"].int
        self.type = json["type"].string
        self.status = json["status"].int
        self.userId = json["userId"].string
        self.appId = json["appId"].string
        self.input = json["input"].string
        self.output = json["output"].string
        self.identifier = json["identifier"].string
        self.completionExpectedAt = json["completionExpectedAt"].double
    }

    static func factories(data: JSON) -> [NKTextProcessingTask]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NKTextProcessingTask.init)
    }

    static func factory(data: JSON) -> NKTextProcessingTask? {
        NKTextProcessingTask.init(json: data)
    }
}

