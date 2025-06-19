
import Foundation

public struct NKEditorDetailsResponse: Codable {
    public let ocs: OCS

    public struct OCS: Codable {
        public let data: DataClass

        public struct DataClass: Codable {
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
    public let name: String
    public let mimetypes: [String]
    public let optionalMimetypes: [String]?
    public let secure: Int
}

public struct NKEditorDetailsCreator: Codable, Sendable {
    public let editor: String
    public let `extension`: String
    public let id: String
    public let mimetype: String
    public let name: String
    public let templates: Int
}

public struct NKEditorTemplate: Codable, Sendable {
    public let `extension`: String
    public let id: String
    public let name: String
    public let preview: String
}
