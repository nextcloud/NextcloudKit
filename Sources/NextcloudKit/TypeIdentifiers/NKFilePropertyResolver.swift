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

    public func resolve(inUTI: String, capabilities: NKCapabilities.Capabilities) -> NKFileProperty {
        let fileProperty = NKFileProperty()
        let typeIdentifier = inUTI as String
        let utiString = inUTI as String

        // Preferred extension
        if let type = UTType(utiString),
           let ext = type.preferredFilenameExtension {
            fileProperty.ext = ext
        }

        // Collabora Nextcloud Text Office
        if capabilities.richDocumentsMimetypes.contains(typeIdentifier) {
            fileProperty.classFile = .document
            fileProperty.iconName = .document
            fileProperty.name = "document"

            return fileProperty
        }

        // Special-case identifiers
        switch typeIdentifier {
        case "text/plain", "text/html", "net.daringfireball.markdown", "text/x-markdown":
            fileProperty.classFile = .document
            fileProperty.iconName = .document
            fileProperty.name = "markdown"
            return fileProperty
        case "com.microsoft.word.doc":
            fileProperty.classFile = .document
            fileProperty.iconName = .document
            fileProperty.name = "document"
            return fileProperty
        case "com.apple.iwork.keynote.key":
            fileProperty.classFile = .document
            fileProperty.iconName = .ppt
            fileProperty.name = "keynote"
            return fileProperty
        case "com.microsoft.excel.xls":
            fileProperty.classFile = .document
            fileProperty.iconName = .xls
            fileProperty.name = "sheet"
            return fileProperty
        case "com.apple.iwork.numbers.numbers":
            fileProperty.classFile = .document
            fileProperty.iconName = .xls
            fileProperty.name = "numbers"
            return fileProperty
        case "com.microsoft.powerpoint.ppt":
            fileProperty.classFile = .document
            fileProperty.iconName = .ppt
            fileProperty.name = "presentation"
        default:
            break
        }

        // Well-known UTI type classifications
        if let type = UTType(utiString) {
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

            } else if type.conforms(to: .zip) {
                fileProperty.classFile = .compress
                fileProperty.iconName = .compress
                fileProperty.name = "archive"

            } else if type.conforms(to: .html) {
                fileProperty.classFile = .document
                fileProperty.iconName = .code
                fileProperty.name = "code"

            } else if type.conforms(to: .pdf) {
                fileProperty.classFile = .document
                fileProperty.iconName = .pdf
                fileProperty.name = "document"

            } else if type.conforms(to: .rtf) {
                fileProperty.classFile = .document
                fileProperty.iconName = .txt
                fileProperty.name = "document"

            } else if type.conforms(to: .text) {
                // Default to .txt if extension is empty
                if fileProperty.ext.isEmpty {
                    fileProperty.ext = "txt"
                }
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
        } else {
            // tipo UTI non valido
            fileProperty.classFile = .unknow
            fileProperty.iconName = .unknow
            fileProperty.name = "file"
        }

        return fileProperty
    }
}
