// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// MARK: - OCS Response Wrapper

public struct OCSTaskTypesResponse: Codable {
    public let ocs: OCSTaskTypesOCS

    public struct OCSTaskTypesOCS: Codable {
        public let data: OCSTaskTypesData
    }

    public struct OCSTaskTypesData: Codable {
        public let types: [String: TaskTypeData]
    }
}

// MARK: - Task Type Models

public struct TaskTypes: Codable {
    public let types: [TaskTypeData]

    public init(types: [TaskTypeData]) {
        self.types = types
    }
}

public struct TaskTypeData: Codable {
    public var id: String?
    public let name: String?
    public let description: String?
    public let inputShape: TaskInputShape?
    public let outputShape: TaskOutputShape?

    public init(id: String?, name: String?, description: String?, inputShape: TaskInputShape?, outputShape: TaskOutputShape?) {
        self.id = id
        self.name = name
        self.description = description
        self.inputShape = inputShape
        self.outputShape = outputShape
    }
}

public struct TaskInputShape: Codable {
    public let input: Shape?

    public init(input: Shape?) {
        self.input = input
    }
}

public struct TaskOutputShape: Codable {
    public let output: Shape?

    public init(output: Shape?) {
        self.output = output
    }
}

public struct Shape: Codable {
    public let name: String
    public let description: String
    public let type: String

    public init(name: String, description: String, type: String) {
        self.name = name
        self.description = description
        self.type = type
    }
}
