// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

public class NKFileProperty: NSObject {
    public var classFile: NKTypeClassFile = .unknow
    public var iconName: NKTypeIconFile = .unknow
    public var name: String = ""
    public var ext: String = ""
}

public enum NKTypeClassFile: String {
    case audio = "audio"
    case compress = "compress"
    case directory = "directory"
    case document = "document"
    case image = "image"
    case unknow = "unknow"
    case url = "url"
    case video = "video"
}

public enum NKTypeIconFile: String {
    case audio = "audio"
    case code = "code"
    case compress = "compress"
    case directory = "directory"
    case document = "document"
    case draw = "draw"
    case image = "image"
    case video = "video"
    case pdf = "pdf"
    case ppt = "ppt"
    case txt = "txt"
    case unknow = "file"
    case url = "url"
    case xls = "xls"
}

/// Class responsible for resolving NKFileProperty information from a given UTI.
public final class NKFilePropertyResolver {

    public init() {}

    public func resolve(
        mimeType: String,
        fileExtension: String,
        typeIdentifier: String,
        capabilities: NKCapabilities.Capabilities
    ) -> NKFileProperty {

        let fileProperty = NKFileProperty()
        let normalizedFileExtension = fileExtension.lowercased()
        let normalizedMimeType = mimeType.lowercased()
        fileProperty.ext = fileExtension

        // MARK: - Custom MIME types

        switch normalizedMimeType {

        case "text/markdown", "text/x-markdown":
            fileProperty.classFile = .document
            fileProperty.iconName = .txt
            fileProperty.name = "text"
            fileProperty.ext = fileExtension.isEmpty ? "md" : fileExtension
            return fileProperty

        case "application/vnd.excalidraw+json":
            fileProperty.classFile = .document
            fileProperty.iconName = .draw
            fileProperty.name = "whiteboard"
            return fileProperty

        case "video/x-matroska", "video/matroska", "video/webm":
            fileProperty.classFile = .video
            fileProperty.iconName = .video
            fileProperty.name = "movie"
            return fileProperty

        case "audio/x-matroska", "audio/matroska", "audio/webm":
            fileProperty.classFile = .audio
            fileProperty.iconName = .audio
            fileProperty.name = "audio"
            return fileProperty

        default:
            break
        }

        // MARK: - Custom file extensions

        switch normalizedFileExtension {

        case "md", "markdown":
            fileProperty.classFile = .document
            fileProperty.iconName = .txt
            fileProperty.name = "text"
            fileProperty.ext = fileExtension.isEmpty ? "md" : fileExtension
            return fileProperty

        case "txt", "text", "log", "csv", "tsv":
            fileProperty.classFile = .document
            fileProperty.iconName = .txt
            fileProperty.name = "text"
            return fileProperty

        case "swift", "m", "mm", "h", "c", "cpp", "hpp",
             "java", "kt", "js", "ts", "html", "css",
             "xml", "json", "yaml", "yml", "php", "py",
             "rb", "go", "rs", "sh", "sql":
            fileProperty.classFile = .document
            fileProperty.iconName = .txt
            fileProperty.name = "text"
            return fileProperty

        case "whiteboard":
            fileProperty.classFile = .document
            fileProperty.iconName = .draw
            fileProperty.name = "whiteboard"
            return fileProperty

        case "mkv", "mk3d", "mks", "webm":
            fileProperty.classFile = .video
            fileProperty.iconName = .video
            fileProperty.name = "movie"
            return fileProperty

        case "mka":
            fileProperty.classFile = .audio
            fileProperty.iconName = .audio
            fileProperty.name = "audio"
            return fileProperty

        default:
            break
        }

        // MARK: - Collabora / Office

        if capabilities.richDocumentsMimetypes.contains(mimeType) || capabilities.richDocumentsMimetypes.contains(normalizedMimeType) {
            fileProperty.classFile = .document
            fileProperty.iconName = .document
            fileProperty.name = "document"
            return fileProperty
        }

        // MARK: - Resolve UTType

        guard let type =
            UTType(mimeType: mimeType) ??
            UTType(typeIdentifier)
        else {
            fileProperty.classFile = .unknow
            fileProperty.iconName = .unknow
            fileProperty.name = "file"
            return fileProperty
        }

        // MARK: - Type conformance

        if type.conforms(to: .image) {

            fileProperty.classFile = .image
            fileProperty.iconName = .image
            fileProperty.name = "image"

        } else if type.conforms(to: .movie) {

            fileProperty.classFile = .video
            fileProperty.iconName = .video
            fileProperty.name = "movie"

        } else if type.conforms(to: .audio) {

            fileProperty.classFile = .audio
            fileProperty.iconName = .audio
            fileProperty.name = "audio"

        } else if type.conforms(to: .text) {

            fileProperty.classFile = .document
            fileProperty.iconName = .txt
            fileProperty.name = "text"

        } else if type.conforms(to: .content) {

            fileProperty.classFile = .document
            fileProperty.iconName = .document
            fileProperty.name = "document"

        } else {

            fileProperty.classFile = .unknow
            fileProperty.iconName = .unknow
            fileProperty.name = "file"
        }

        return fileProperty
    }
}
