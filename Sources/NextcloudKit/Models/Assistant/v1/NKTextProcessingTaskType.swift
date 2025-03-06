// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftyJSON

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

    static func deserialize(multipleObjects data: JSON) -> [NKTextProcessingTaskType]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NKTextProcessingTaskType.init)
    }

    public static func toV2(type: [NKTextProcessingTaskType]) -> TaskTypes {
        let types = type.map { type in
            TaskTypeData(id: type.id, name: type.name, description: type.description, inputShape: nil, outputShape: nil)
        }

        return TaskTypes(types: types)
    }
}


