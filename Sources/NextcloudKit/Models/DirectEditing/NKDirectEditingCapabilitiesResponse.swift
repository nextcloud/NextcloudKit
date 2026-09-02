// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NKDirectEditingCapabilitiesResponse: Codable, Sendable {
    public let ocs: OCS

    public struct OCS: Codable, Sendable {
        public let data: DataClass

        public struct DataClass: Codable, Sendable {
            public let editors: [String: NKDirectEditingEditor]
            public let creators: [String: NKDirectEditingCreator]
        }
    }
}

public struct NKDirectEditingTemplateResponse: Codable, Sendable {
    public let ocs: OCS

    public struct OCS: Codable, Sendable {
        public let data: DataClass

        public struct DataClass: Codable, Sendable {
            public let templates: [String: NKDirectEditingTemplate]
        }
    }
}

public struct NKDirectEditingTemplate: Codable, Sendable {
    public let ext: String
    public let identifier: String
    public let mimetype: String
    public let name: String
    public let preview: String?

    enum CodingKeys: String, CodingKey {
        case ext = "extension"
        case identifier = "id"
        case mimetype
        case name = "title"
        case preview
    }

    public init(
        ext: String = "",
        identifier: String = "",
        mimetype: String = "",
        name: String = "",
        preview: String? = nil
    ) {
        self.ext = ext
        self.identifier = identifier
        self.mimetype = mimetype
        self.name = name
        self.preview = preview
    }
}

public struct NKDirectEditingEditor: Codable, Sendable {
    public let identifier: String
    public let mimetypes: [String]
    public let name: String
    public let optionalMimetypes: [String]
    public let secure: Bool

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case mimetypes
        case name
        case optionalMimetypes
        case secure
    }
}

public struct NKDirectEditingCreator: Codable, Sendable {
    public let identifier: String
    public let templates: Bool
    public let mimetype: String
    public let name: String
    public let editor: String
    public let ext: String

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case templates
        case mimetype
        case name
        case editor
        case ext = "extension"
    }
}
