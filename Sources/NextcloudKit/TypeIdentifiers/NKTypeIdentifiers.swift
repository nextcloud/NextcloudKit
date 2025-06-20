// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

public struct NKTypeIdentifierCache: Sendable {
    public let mimeType: String
    public let classFile: String
    public let iconName: String
    public let typeIdentifier: String
    public let fileNameWithoutExt: String
    public let ext: String
}

/// Actor responsible for resolving file type metadata (UTI, MIME type, icon, class file, etc.) in a thread-safe manner.
public actor NKTypeIdentifiers {
    private var filePropertyCache: [String: NKTypeIdentifierCache] = [:]
    private var mimeTypeCache: [String: String] = [:]
    private var filePropertiesCache: [String: NKFileProperty] = [:]
    private let resolver = NKFilePropertyResolver()

    public init() {}

    /// Resolves internal type metadata for a given file.
    public func getInternalType(fileName: String, mimeType inputMimeType: String, directory: Bool, account: String) -> NKTypeIdentifierCache {
        // Extract file extension
        var ext = (fileName as NSString).pathExtension.lowercased()
        var mimeType = inputMimeType
        var classFile = ""
        var iconName = ""
        var typeIdentifier = ""
        var fileNameWithoutExt = (fileName as NSString).deletingPathExtension

        // Try cached result
        if let cached = filePropertyCache[ext] {
            return cached
        }

        // Resolve UTI from extension
        guard let type = UTType(filenameExtension: ext) else {
            return NKTypeIdentifierCache(
                mimeType: mimeType,
                classFile: classFile,
                iconName: iconName,
                typeIdentifier: typeIdentifier,
                fileNameWithoutExt: fileNameWithoutExt,
                ext: ext
            )
        }

        let uti = type.identifier
        typeIdentifier = uti

        // Detect MIME type from UTI
        if mimeType.isEmpty {
            if let cachedMime = mimeTypeCache[typeIdentifier] {
                mimeType = cachedMime
            } else if let mime = UTType(typeIdentifier)?.preferredMIMEType {
                mimeType = mime
                mimeTypeCache[typeIdentifier] = mime
            }
        }

        // Special case for folders
        if directory {
            mimeType = "httpd/unix-directory"
            classFile = NKTypeClassFile.directory.rawValue
            iconName = NKTypeIconFile.directory.rawValue
            typeIdentifier = UTType.folder.identifier
            fileNameWithoutExt = fileName
            ext = ""
        } else {
            // Lookup file classification and icon
            let fileProps: NKFileProperty
            if let cachedProps = filePropertiesCache[typeIdentifier] {
                fileProps = cachedProps
            } else {
                fileProps = resolver.resolve(inUTI: typeIdentifier, account: account)
                filePropertiesCache[typeIdentifier] = fileProps
            }

            classFile = fileProps.classFile.rawValue
            iconName = fileProps.iconName.rawValue
        }

        // Step 7: Assemble cache object
        let result = NKTypeIdentifierCache(
            mimeType: mimeType,
            classFile: classFile,
            iconName: iconName,
            typeIdentifier: typeIdentifier,
            fileNameWithoutExt: fileNameWithoutExt,
            ext: ext
        )

        // Step 8: Cache result for reuse
        filePropertyCache[ext] = result
        return result
    }
}

public final class NKTypeIdentifiersHelper {
    private let actor: NKTypeIdentifiers

    public init(actor: NKTypeIdentifiers) {
        self.actor = actor
    }

    public func getInternalTypeSync(fileName: String, mimeType: String, directory: Bool, account: String) -> NKTypeIdentifierCache {
        var result: NKTypeIdentifierCache?
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            result = await actor.getInternalType(
                fileName: fileName,
                mimeType: mimeType,
                directory: directory,
                account: account
            )
            semaphore.signal()
        }

        semaphore.wait()
        return result!
    }
}
