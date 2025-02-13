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

    static func factory(data: JSON) -> [NKTextProcessingTaskType]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NKTextProcessingTaskType.init)
    }
}


