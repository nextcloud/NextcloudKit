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
    public typealias TaskInputShape = [String: Shape]
    public typealias TaskOutputShape = [String: Shape]
    
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

    public func isChat() -> Bool {
        id == "core:text2text:chat"
    }

    public func isTranslate() -> Bool {
        id?.contains("translate") == true
    }

    public func isSingleTextInputOutput(supportedTaskType: String = "Text") -> Bool {
        guard let inputShape, let outputShape else { return false }
        return inputShape.count == 1 &&
               outputShape.count == 1 &&
               inputShape.values.first?.type == supportedTaskType &&
               outputShape.values.first?.type == supportedTaskType
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
