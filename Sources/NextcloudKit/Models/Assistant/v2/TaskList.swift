// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// MARK: - OCS Response Wrappers

public struct OCSTaskListResponse: Codable {
    public let ocs: OCSTaskListOCS

    public struct OCSTaskListOCS: Codable {
        public let data: OCSTaskListData
    }

    public struct OCSTaskListData: Codable {
        public let tasks: [AssistantTask]
    }
}

public struct OCSTaskResponse: Codable {
    public let ocs: OCSTaskOCS

    public struct OCSTaskOCS: Codable {
        public let data: OCSTaskData
    }

    public struct OCSTaskData: Codable {
        public let task: AssistantTask
    }
}

// MARK: - Task Models

public struct TaskList: Codable {
    public var tasks: [AssistantTask]

    public init(tasks: [AssistantTask]) {
        self.tasks = tasks
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
