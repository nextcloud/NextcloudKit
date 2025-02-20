// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftyJSON

public struct TaskList: Codable {
    public var tasks: [AssistantTask]

    static func factory(from data: JSON) -> TaskList? {
        let tasks = data.arrayValue.map { taskJson in
            AssistantTask(
                id: taskJson["id"].int64Value,
                type: taskJson["type"].string,
                status: taskJson["status"].string,
                userId: taskJson["userId"].string,
                appId: taskJson["appId"].string,
                input: TaskInput(input: taskJson["input"]["input"].string),
                output: TaskOutput(output: taskJson["output"]["output"].string),
                completionExpectedAt: taskJson["completionExpectedAt"].int,
                progress: taskJson["progress"].int,
                lastUpdated: taskJson["lastUpdated"].int,
                scheduledAt: taskJson["scheduledAt"].int,
                endedAt: taskJson["endedAt"].int
            )
        }

        return TaskList(tasks: tasks)
    }
}

public struct AssistantTask: Codable {
    public let id: Int64
    public let type: String?
    public let status: String?
    public let userId: String?
    public let appId: String?
    public let input: TaskInput?
    public let output: TaskOutput?
    public let completionExpectedAt: Int?
    public var progress: Int?
    public let lastUpdated: Int?
    public let scheduledAt: Int?
    public let endedAt: Int?

    public init(id: Int64, type: String?, status: String?, userId: String?, appId: String?, input: TaskInput?, output: TaskOutput?, completionExpectedAt: Int?, progress: Int? = nil, lastUpdated: Int?, scheduledAt: Int?, endedAt: Int?) {
        self.id = id
        self.type = type
        self.status = status
        self.userId = userId
        self.appId = appId
        self.input = input
        self.output = output
        self.completionExpectedAt = completionExpectedAt
        self.progress = progress
        self.lastUpdated = lastUpdated
        self.scheduledAt = scheduledAt
        self.endedAt = endedAt
    }

    static func factory(from data: JSON) -> AssistantTask? {
        let task = AssistantTask(
            id: data["id"].int64Value,
            type: data["type"].string,
            status: data["status"].string,
            userId: data["userId"].string,
            appId: data["appId"].string,
            input: TaskInput(input: data["input"]["input"].string),
            output: TaskOutput(output: data["output"]["output"].string),
            completionExpectedAt: data["completionExpectedAt"].int,
            progress: data["progress"].int,
            lastUpdated: data["lastUpdated"].int,
            scheduledAt: data["scheduledAt"].int,
            endedAt: data["endedAt"].int
        )

        return task
    }
}

public struct TaskInput: Codable {
    public var input: String?

    public init(input: String? = nil) {
        self.input = input
    }
}

public struct TaskOutput: Codable {
    public var output: String?

    public init(output: String? = nil) {
        self.output = output
    }
}


