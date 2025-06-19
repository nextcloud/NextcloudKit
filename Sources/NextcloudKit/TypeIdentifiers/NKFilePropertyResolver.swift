// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MobileCoreServices

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

    public func resolve(inUTI: CFString, account: String) -> NKFileProperty {
        let fileProperty = NKFileProperty()
        let typeIdentifier = inUTI as String
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: account)

        // Preferred extension
        if let fileExtension = UTTypeCopyPreferredTagWithClass(inUTI, kUTTagClassFilenameExtension) {
            fileProperty.ext = fileExtension.takeRetainedValue() as String
        }

        // Well-known UTI type classifications
        if UTTypeConformsTo(inUTI, kUTTypeImage) {
            fileProperty.classFile = .image
            fileProperty.iconName = .image
            fileProperty.name = "image"
        } else if UTTypeConformsTo(inUTI, kUTTypeMovie) {
            fileProperty.classFile = .video
            fileProperty.iconName = .video
            fileProperty.name = "movie"
        } else if UTTypeConformsTo(inUTI, kUTTypeAudio) {
            fileProperty.classFile = .audio
            fileProperty.iconName = .audio
            fileProperty.name = "audio"
        } else if UTTypeConformsTo(inUTI, kUTTypeZipArchive) {
            fileProperty.classFile = .compress
            fileProperty.iconName = .compress
            fileProperty.name = "archive"
        } else if UTTypeConformsTo(inUTI, kUTTypeHTML) {
            fileProperty.classFile = .document
            fileProperty.iconName = .code
            fileProperty.name = "code"
        } else if UTTypeConformsTo(inUTI, kUTTypePDF) {
            fileProperty.classFile = .document
            fileProperty.iconName = .pdf
            fileProperty.name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeRTF) {
            fileProperty.classFile = .document
            fileProperty.iconName = .txt
            fileProperty.name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeText) {
            if fileProperty.ext.isEmpty { fileProperty.ext = "txt" }
            fileProperty.classFile = .document
            fileProperty.iconName = .txt
            fileProperty.name = "text"
        } else {
            // Special-case identifiers
            switch typeIdentifier {
            case "text/plain", "text/html", "net.daringfireball.markdown", "text/x-markdown":
                fileProperty.classFile = .document
                fileProperty.iconName = .document
                fileProperty.name = "markdown"

            case "com.microsoft.word.doc":
                fileProperty.classFile = .document
                fileProperty.iconName = .document
                fileProperty.name = "document"

            case "com.apple.iwork.keynote.key":
                fileProperty.classFile = .document
                fileProperty.iconName = .ppt
                fileProperty.name = "keynote"

            case "com.microsoft.excel.xls":
                fileProperty.classFile = .document
                fileProperty.iconName = .xls
                fileProperty.name = "sheet"

            case "com.apple.iwork.numbers.numbers":
                fileProperty.classFile = .document
                fileProperty.iconName = .xls
                fileProperty.name = "numbers"

            case "com.microsoft.powerpoint.ppt":
                fileProperty.classFile = .document
                fileProperty.iconName = .ppt
                fileProperty.name = "presentation"

            default:
                // Check against Collabora mimetypes
                if capabilities.richDocumentsMimetypes.contains(typeIdentifier) {
                    fileProperty.classFile = .document
                    fileProperty.iconName = .document
                    fileProperty.name = "document"
                } else if UTTypeConformsTo(inUTI, kUTTypeContent) {
                    fileProperty.classFile = .document
                    fileProperty.iconName = .document
                    fileProperty.name = "document"
                } else {
                    fileProperty.classFile = .unknow
                    fileProperty.iconName = .unknow
                    fileProperty.name = "file"
                }
            }
        }

        return fileProperty
    }
}
