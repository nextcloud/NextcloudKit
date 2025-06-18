
import Foundation
import UniformTypeIdentifiers

public struct UTTypeConformsToServer: Sendable, Equatable, Hashable, Codable {
    public let typeIdentifier: String
    public let classFile: String
    public let editor: String
    public let iconName: String
    public let name: String
    public let account: String

    public init(
        typeIdentifier: String,
        classFile: String,
        editor: String,
        iconName: String,
        name: String,
        account: String
    ) {
        self.typeIdentifier = typeIdentifier
        self.classFile = classFile
        self.editor = editor
        self.iconName = iconName
        self.name = name
        self.account = account
    }
}

public enum TypeClassFile: String, CaseIterable, Codable, Equatable, Sendable {
    case audio
    case compress
    case directory
    case document
    case image
    case unknow
    case url
    case video

    /// Optional: human-readable label (useful for UI or logs)
    public var displayName: String {
        switch self {
        case .audio: return "Audio"
        case .compress: return "Compressed"
        case .directory: return "Folder"
        case .document: return "Document"
        case .image: return "Image"
        case .unknow: return "Unknown"
        case .url: return "URL"
        case .video: return "Video"
        }
    }
}

public enum TypeIconFile: String, CaseIterable, Codable, Equatable, Sendable {
    case audio
    case code
    case compress
    case directory
    case document
    case image
    case movie
    case pdf
    case ppt
    case txt
    case unknow = "file"
    case url
    case xls

    /// Optional: Human-readable label
    public var displayName: String {
        switch self {
        case .audio: return "Audio"
        case .code: return "Code"
        case .compress: return "Compressed"
        case .directory: return "Folder"
        case .document: return "Document"
        case .image: return "Image"
        case .movie: return "Movie"
        case .pdf: return "PDF"
        case .ppt: return "PowerPoint"
        case .txt: return "Text"
        case .unknow: return "Unknown"
        case .url: return "Link"
        case .xls: return "Excel"
        }
    }
}

extension UTType {
    static let zipArchive = UTType(importedAs: "public.zip-archive")
}

/// Thread-safe actor to manage UTI resolution, MIME types, file classification and custom overrides
actor NKTypeIdentifiers {
    static let shared = NKTypeIdentifiers()

    private var utiCache: [String: String] = [:]                     // ext -> UTI identifier
    private var mimeTypeCache: [String: String] = [:]               // UTI identifier -> MIME type
    private var filePropertiesCache: [String: NKFileProperty] = [:] // UTI identifier -> NKFileProperty
    private var internalTypeIdentifiers: [UTTypeConformsToServer] = []

    // MARK: - Public Methods

    func clearInternalTypeIdentifier(account: String) {
        internalTypeIdentifiers.removeAll { $0.account == account }
    }

    func addInternalTypeIdentifier(typeIdentifier: String, classFile: String, editor: String, iconName: String, name: String, account: String) {
        let exists = internalTypeIdentifiers.contains {
            $0.typeIdentifier == typeIdentifier &&
            $0.editor == editor &&
            $0.account == account
        }

        if !exists {
            let newUTI = UTTypeConformsToServer(
                typeIdentifier: typeIdentifier,
                classFile: classFile,
                editor: editor,
                iconName: iconName,
                name: name,
                account: account
            )
            internalTypeIdentifiers.append(newUTI)
        }
    }

    func getInternalType(fileName: String, mimeType inputMimeType: String, directory: Bool, account: String) -> (mimeType: String, classFile: String, iconName: String, typeIdentifier: String, fileNameWithoutExt: String, ext: String) {

        var ext = (fileName as NSString).pathExtension.lowercased()
        var mimeType = inputMimeType
        var classFile = "", iconName = "", typeIdentifier = "", fileNameWithoutExt = ""
        var resolvedUTI: UTType?

        if let cachedUTIId = utiCache[ext], let cachedUTI = UTType(cachedUTIId) {
            resolvedUTI = cachedUTI
        } else if let newUTI = UTType(filenameExtension: ext) {
            resolvedUTI = newUTI
            utiCache[ext] = newUTI.identifier
        }

        if let uti = resolvedUTI {
            typeIdentifier = uti.identifier
            fileNameWithoutExt = (fileName as NSString).deletingPathExtension

            if mimeType.isEmpty {
                if let cachedMime = mimeTypeCache[uti.identifier] {
                    mimeType = cachedMime
                } else if let preferredMime = uti.preferredMIMEType {
                    mimeType = preferredMime
                    mimeTypeCache[uti.identifier] = preferredMime
                }
            }

            if directory {
                mimeType = "httpd/unix-directory"
                classFile = TypeClassFile.directory.rawValue
                iconName = TypeIconFile.directory.rawValue
                typeIdentifier = UTType.folder.identifier
                fileNameWithoutExt = fileName
                ext = ""
            } else {
                var fileProperty: NKFileProperty

                if let cached = filePropertiesCache[uti.identifier] {
                    fileProperty = cached
                } else {
                    fileProperty = getFileProperties(for: uti)
                    filePropertiesCache[uti.identifier] = fileProperty
                }

                classFile = fileProperty.classFile
                iconName = fileProperty.iconName
            }
        }

        return (mimeType, classFile, iconName, typeIdentifier, fileNameWithoutExt, ext)
    }

    func getFileProperties(for uti: UTType) -> NKFileProperty {
        let fileProperty = NKFileProperty()

        if let ext = uti.preferredFilenameExtension {
            fileProperty.ext = ext
        }

        if uti.conforms(to: .image) {
            fileProperty.classFile = TypeClassFile.image.rawValue
            fileProperty.iconName = TypeIconFile.image.rawValue
            fileProperty.name = "image"
        } else if uti.conforms(to: .movie) {
            fileProperty.classFile = TypeClassFile.video.rawValue
            fileProperty.iconName = TypeIconFile.movie.rawValue
            fileProperty.name = "movie"
        } else if uti.conforms(to: .audio) {
            fileProperty.classFile = TypeClassFile.audio.rawValue
            fileProperty.iconName = TypeIconFile.audio.rawValue
            fileProperty.name = "audio"
        } else if uti.conforms(to: .zipArchive) {
            fileProperty.classFile = TypeClassFile.compress.rawValue
            fileProperty.iconName = TypeIconFile.compress.rawValue
            fileProperty.name = "archive"
        } else if uti.conforms(to: .html) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.code.rawValue
            fileProperty.name = "code"
        } else if uti.conforms(to: .pdf) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.pdf.rawValue
            fileProperty.name = "document"
        } else if uti.conforms(to: .rtf) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.txt.rawValue
            fileProperty.name = "document"
        } else if uti.conforms(to: .plainText) {
            if fileProperty.ext.isEmpty { fileProperty.ext = "txt" }
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.txt.rawValue
            fileProperty.name = "text"
        } else {
            if let result = internalTypeIdentifiers.first(where: { $0.typeIdentifier == uti.identifier }) {
                fileProperty.classFile = result.classFile
                fileProperty.iconName = result.iconName
                fileProperty.name = result.name
            } else if uti.conforms(to: .content) {
                fileProperty.classFile = TypeClassFile.document.rawValue
                fileProperty.iconName = TypeIconFile.document.rawValue
                fileProperty.name = "document"
            } else {
                fileProperty.classFile = TypeClassFile.unknow.rawValue
                fileProperty.iconName = TypeIconFile.unknow.rawValue
                fileProperty.name = "file"
            }
        }

        return fileProperty
    }
}

