// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftyJSON

//public class NKTextProcessingTaskV2 {
//    public var id: Int?
//    public var type: String?
//    public var status: Int?
//    public var userId: String?
//    public var appId: String?
//    public var input: String?
//    public var output: String?
//    public var identifier: String?
//    public var completionExpectedAt: Double?
//
//    public init(id: Int? = nil, type: String? = nil, status: Int? = nil, userId: String? = nil, appId: String? = nil, input: String? = nil, output: String? = nil, identifier: String? = nil, completionExpectedAt: Double? = nil) {
//        self.id = id
//        self.type = type
//        self.status = status
//        self.userId = userId
//        self.appId = appId
//        self.input = input
//        self.output = output
//        self.identifier = identifier
//        self.completionExpectedAt = completionExpectedAt
//    }
//
//    public init?(json: JSON) {
//        self.id = json["id"].int
//        self.type = json["type"].string
//        self.status = json["status"].int
//        self.userId = json["userId"].string
//        self.appId = json["appId"].string
//        self.input = json["input"].string
//        self.output = json["output"].string
//        self.identifier = json["identifier"].string
//        self.completionExpectedAt = json["completionExpectedAt"].double
//    }
//
//    static func factories(data: JSON) -> [NKTextProcessingTask]? {
//        guard let allResults = data.array else { return nil }
//        return allResults.compactMap(NKTextProcessingTask.init)
//    }
//
//    static func factory(data: JSON) -> NKTextProcessingTask? {
//        NKTextProcessingTask(json: data)
//    }
//}

public struct NKTextProcessingTaskV2 {
    public struct TaskList: Codable {
        public var tasks: [Task]
    }

    public struct Task: Codable {
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
    }

    public struct TaskInput: Codable {
        public var input: String?
    }

    public struct TaskOutput: Codable {
        public var output: String?
    }

    static func parseTaskList(from data: JSON) -> NKTextProcessingTaskV2.TaskList? {
//        guard let data = jsonString.data(using: .utf8) else { return nil }

        do {
//            let json = try JSON(data: data)
//            let tasksArray = json["ocs"]["data"]["tasks"]

            let tasks = data.arrayValue.map { taskJson in
                NKTextProcessingTaskV2.Task(
                    id: taskJson["id"].int64Value,
                    type: taskJson["type"].string,
                    status: taskJson["status"].string,
                    userId: taskJson["userId"].string,
                    appId: taskJson["appId"].string,
                    input: NKTextProcessingTaskV2.TaskInput(input: taskJson["input"]["input"].string),
                    output: NKTextProcessingTaskV2.TaskOutput(output: taskJson["output"]["output"].string),
                    completionExpectedAt: taskJson["completionExpectedAt"].int,
                    progress: taskJson["progress"].int,
                    lastUpdated: taskJson["lastUpdated"].int,
                    scheduledAt: taskJson["scheduledAt"].int,
                    endedAt: taskJson["endedAt"].int
                )
            }

            return NKTextProcessingTaskV2.TaskList(tasks: tasks)
        } catch {
            print("Failed to parse JSON: \(error)")
            return nil
        }
    }
}
