// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftyJSON

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
        NKTextProcessingTask(json: data)
    }

    static func toV2(tasks: [NKTextProcessingTask]) -> TaskList {
        let tasks = tasks.map { task in
            AssistantTask(
                id: Int64(task.id ?? 0),
                type: task.type,
                status: String(task.status ?? 0),
                userId: task.userId,
                appId: task.appId,
                input: TaskInput(input: task.input),
                output: TaskOutput(output: task.output),
                completionExpectedAt: Int(task.completionExpectedAt ?? 0),
                progress: nil,
                lastUpdated: nil,
                scheduledAt: nil,
                endedAt: nil
            )
        }

        return TaskList(tasks: tasks)
    }
}
