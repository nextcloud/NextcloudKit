
import Foundation

public struct NKEditorDetailsResponse: Codable, Sendable {
    public let ocs: OCS

    public struct OCS: Codable, Sendable {
        public let data: DataClass

        public struct DataClass: Codable, Sendable {
            public let editors: [String: NKEditorDetailsEditor]
            public let creators: [String: NKEditorDetailsCreator]
        }
    }
}

public struct NKEditorTemplateResponse: Codable, Sendable {
    public let ocs: OCS

    public struct OCS: Codable, Sendable {
        public let data: DataClass

        public struct DataClass: Codable, Sendable {
            public let editors: [NKEditorTemplate]
        }
    }
}

public struct NKEditorDetailsEditor: Codable, Sendable {
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

public struct NKEditorDetailsCreator: Codable, Sendable {
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

public struct NKEditorTemplate: Codable, Sendable {
    public let ext: String
    public let identifier: String
    public let name: String
    public let preview: String

    enum CodingKeys: String, CodingKey {
        case ext = "extension"
        case identifier = "id"
        case name
        case preview
    }
}
