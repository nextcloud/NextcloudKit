
import Foundation
import MobileCoreServices

/// Actor responsible for resolving file type metadata (UTI, MIME type, icon, class file, etc.) in a thread-safe manner.
public actor NKTypeIdentifiers {

    private var utiCache: [String: String] = [:]
    private var mimeTypeCache: [String: String] = [:]
    private var filePropertiesCache: [String: NKFileProperty] = [:]
    private let resolver = NKFilePropertyResolver()

    public init() {}

    /// Resolves internal type metadata for a given file.
    public func getInternalType(fileName: String,
                                mimeType inputMimeType: String,
                                directory: Bool,
                                account: String) -> (
        mimeType: String,
        classFile: String,
        iconName: String,
        typeIdentifier: String,
        fileNameWithoutExt: String,
        ext: String
    ) {
        var ext = (fileName as NSString).pathExtension.lowercased()
        var mimeType = inputMimeType
        var classFile = ""
        var iconName = ""
        var typeIdentifier = ""
        var fileNameWithoutExt = ""

        var uti: CFString?

        // UTI cache
        if let cachedUTI = utiCache[ext] {
            uti = cachedUTI as CFString
        } else if let unmanagedUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil) {
            let resolvedUTI = unmanagedUTI.takeRetainedValue()
            uti = resolvedUTI
            utiCache[ext] = resolvedUTI as String
        }

        if let uti {
            typeIdentifier = uti as String
            fileNameWithoutExt = (fileName as NSString).deletingPathExtension

            // MIME type detection
            if mimeType.isEmpty {
                if let cachedMime = mimeTypeCache[typeIdentifier] {
                    mimeType = cachedMime
                } else if let mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType) {
                    let mimeStr = mime.takeRetainedValue() as String
                    mimeType = mimeStr
                    mimeTypeCache[typeIdentifier] = mimeStr
                }
            }

            // Directory override
            if directory {
                mimeType = "httpd/unix-directory"
                classFile = TypeClassFile.directory.rawValue
                iconName = TypeIconFile.directory.rawValue
                typeIdentifier = kUTTypeFolder as String
                fileNameWithoutExt = fileName
                ext = ""
            } else {
                let fileProps: NKFileProperty

                if let cached = filePropertiesCache[typeIdentifier] {
                    fileProps = cached
                } else {
                    fileProps = resolver.resolve(inUTI: uti, account: account)
                    filePropertiesCache[typeIdentifier] = fileProps
                }

                classFile = fileProps.classFile
                iconName = fileProps.iconName
            }
        }

        return (
            mimeType: mimeType,
            classFile: classFile,
            iconName: iconName,
            typeIdentifier: typeIdentifier,
            fileNameWithoutExt: fileNameWithoutExt,
            ext: ext
        )
    }
}
