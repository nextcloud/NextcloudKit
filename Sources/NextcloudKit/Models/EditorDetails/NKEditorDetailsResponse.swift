
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
    public let id: String
    public let mimetypes: [String]
    public let name: String
    public let optionalMimetypes: [String]
    public let secure: Bool
}

public struct NKEditorDetailsCreator: Codable, Sendable {
    public let id: String
    public let templates: Bool
    public let mimetype: String
    public let name: String
    public let editor: String
    public let `extension`: String
}

public struct NKEditorTemplate: Codable, Sendable {
    public let `extension`: String
    public let id: String
    public let name: String
    public let preview: String
}
