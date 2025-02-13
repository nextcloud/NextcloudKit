// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftyJSON

//public class NKTextProcessingTaskTypeV2 {
//    public var id: String?
//    public var name: String?
//    public var description: String?
//
//    public init(id: String? = nil, name: String? = nil, description: String? = nil) {
//        self.id = id
//        self.name = name
//        self.description = description
//    }
//
//    public init?(json: JSON) {
//        self.id = json["id"].string
//        self.name = json["name"].string
//        self.description = json["description"].string
//    }
//
//    static func factory(data: JSON) -> [NKTextProcessingTaskType]? {
//        guard let allResults = data.array else { return nil }
//        return allResults.compactMap(NKTextProcessingTaskType.init)
//    }
// }

public struct TaskTypes: Codable {
    public let types: [String: TaskTypeData]

    static func factory(data: JSON) -> TaskTypes? {
        var taskTypesDict: [String: TaskTypeData] = [:]

        for (key, subJson) in data {
            let taskTypeData = TaskTypeData(
                id: key,
                name: subJson["name"].string,
                description: subJson["description"].string,
                inputShape: subJson["inputShape"].dictionary != nil ? TaskInputShape(
                    input: subJson["inputShape"]["input"].dictionary != nil ? Shape(
                        name: subJson["inputShape"]["input"]["name"].stringValue,
                        description: subJson["inputShape"]["input"]["description"].stringValue,
                        type: subJson["inputShape"]["input"]["type"].stringValue
                    ) : nil
                ) : nil,
                outputShape: subJson["outputShape"].dictionary != nil ? TaskOutputShape(
                    output: subJson["outputShape"]["output"].dictionary != nil ? Shape(
                        name: subJson["outputShape"]["output"]["name"].stringValue,
                        description: subJson["outputShape"]["output"]["description"].stringValue,
                        type: subJson["outputShape"]["output"]["type"].stringValue
                    ) : nil
                ) : nil
            )

            taskTypesDict[key] = taskTypeData
        }

        let taskTypes = TaskTypes(types: taskTypesDict)
        return taskTypes
    }
}

public struct TaskTypeData: Codable {
    public let id: String?
    public let name: String?
    public let description: String?
    public let inputShape: TaskInputShape?
    public let outputShape: TaskOutputShape?
}

public struct TaskInputShape: Codable {
    public let input: Shape?
}

public struct TaskOutputShape: Codable {
    public let output: Shape?
}

public struct Shape: Codable {
    public let name: String
    public let description: String
    public let type: String
}






