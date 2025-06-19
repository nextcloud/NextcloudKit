import Foundation
import MobileCoreServices

public enum TypeClassFile: String {
    case audio = "audio"
    case compress = "compress"
    case directory = "directory"
    case document = "document"
    case image = "image"
    case unknow = "unknow"
    case url = "url"
    case video = "video"
}

public enum TypeIconFile: String {
    case audio = "audio"
    case code = "code"
    case compress = "compress"
    case directory = "directory"
    case document = "document"
    case image = "image"
    case movie = "movie"
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
            fileProperty.classFile = TypeClassFile.image.rawValue
            fileProperty.iconName = TypeIconFile.image.rawValue
            fileProperty.name = "image"
        } else if UTTypeConformsTo(inUTI, kUTTypeMovie) {
            fileProperty.classFile = TypeClassFile.video.rawValue
            fileProperty.iconName = TypeIconFile.movie.rawValue
            fileProperty.name = "movie"
        } else if UTTypeConformsTo(inUTI, kUTTypeAudio) {
            fileProperty.classFile = TypeClassFile.audio.rawValue
            fileProperty.iconName = TypeIconFile.audio.rawValue
            fileProperty.name = "audio"
        } else if UTTypeConformsTo(inUTI, kUTTypeZipArchive) {
            fileProperty.classFile = TypeClassFile.compress.rawValue
            fileProperty.iconName = TypeIconFile.compress.rawValue
            fileProperty.name = "archive"
        } else if UTTypeConformsTo(inUTI, kUTTypeHTML) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.code.rawValue
            fileProperty.name = "code"
        } else if UTTypeConformsTo(inUTI, kUTTypePDF) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.pdf.rawValue
            fileProperty.name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeRTF) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.txt.rawValue
            fileProperty.name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeText) {
            if fileProperty.ext.isEmpty { fileProperty.ext = "txt" }
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.txt.rawValue
            fileProperty.name = "text"
        } else {
            // Special-case identifiers
            switch typeIdentifier {
            case "text/plain", "text/html", "net.daringfireball.markdown", "text/x-markdown":
                fileProperty.classFile = TypeClassFile.document.rawValue
                fileProperty.iconName = TypeIconFile.document.rawValue
                fileProperty.name = "markdown"

            case "com.microsoft.word.doc":
                fileProperty.classFile = TypeClassFile.document.rawValue
                fileProperty.iconName = TypeIconFile.document.rawValue
                fileProperty.name = "document"

            case "com.apple.iwork.keynote.key":
                fileProperty.classFile = TypeClassFile.document.rawValue
                fileProperty.iconName = TypeIconFile.ppt.rawValue
                fileProperty.name = "keynote"

            case "com.microsoft.excel.xls":
                fileProperty.classFile = TypeClassFile.document.rawValue
                fileProperty.iconName = TypeIconFile.xls.rawValue
                fileProperty.name = "sheet"

            case "com.apple.iwork.numbers.numbers":
                fileProperty.classFile = TypeClassFile.document.rawValue
                fileProperty.iconName = TypeIconFile.xls.rawValue
                fileProperty.name = "numbers"

            case "com.microsoft.powerpoint.ppt":
                fileProperty.classFile = TypeClassFile.document.rawValue
                fileProperty.iconName = TypeIconFile.ppt.rawValue
                fileProperty.name = "presentation"

            default:
                // Check against Collabora mimetypes
                if capabilities.richDocumentsMimetypes.contains(typeIdentifier) {
                    fileProperty.classFile = TypeClassFile.document.rawValue
                    fileProperty.iconName = TypeIconFile.document.rawValue
                    fileProperty.name = "document"
                } else if UTTypeConformsTo(inUTI, kUTTypeContent) {
                    fileProperty.classFile = TypeClassFile.document.rawValue
                    fileProperty.iconName = TypeIconFile.document.rawValue
                    fileProperty.name = "document"
                } else {
                    fileProperty.classFile = TypeClassFile.unknow.rawValue
                    fileProperty.iconName = TypeIconFile.unknow.rawValue
                    fileProperty.name = "file"
                }
            }
        }

        return fileProperty
    }
}
