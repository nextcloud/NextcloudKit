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
/// Actor responsible for resolving file type metadata (UTI, MIME type, icon, etc.) in a thread-safe manner.
public actor NKTypeIdentifiers {
    /// Cache by file extension
    private var typeIdentifierCache: [String: NKTypeIdentifierCache] = [:]
    /// Internal file type resolver
    private let resolver = NKFilePropertyResolver()

    public init() {}

    /// Resolves internal type metadata for a given file.
    public func getInternalType(fileName: String, mimeType inputMimeType: String, directory: Bool, account: String) -> NKTypeIdentifierCache {
        var ext = (fileName as NSString).pathExtension.lowercased()
        var mimeType = inputMimeType
        var classFile = ""
        var iconName = ""
        var typeIdentifier = ""
        var fileNameWithoutExt = (fileName as NSString).deletingPathExtension

        // Check cache
        if let cached = typeIdentifierCache[ext] {
            return cached
        }

        // Fallback if no extension (e.g. ".bashrc" or folder)
        if ext.isEmpty {
            fileNameWithoutExt = fileName
        }

        // Resolve UTType from extension or fallback to .data
        let type = UTType(filenameExtension: ext) ?? .data
        typeIdentifier = type.identifier

        // Resolve MIME type if not provided
        if mimeType.isEmpty {
            mimeType = type.preferredMIMEType ?? "application/octet-stream"
        }

        // Special case: folders
        if directory {
            mimeType = "httpd/unix-directory"
            classFile = NKTypeClassFile.directory.rawValue
            iconName = NKTypeIconFile.directory.rawValue
            typeIdentifier = UTType.folder.identifier
            ext = ""
            fileNameWithoutExt = fileName
        } else {
            let props = resolver.resolve(inUTI: typeIdentifier, account: account)
            classFile = props.classFile.rawValue
            iconName = props.iconName.rawValue
        }

        let result = NKTypeIdentifierCache(
            mimeType: mimeType,
            classFile: classFile,
            iconName: iconName,
            typeIdentifier: typeIdentifier,
            fileNameWithoutExt: fileNameWithoutExt,
            ext: ext
        )

        typeIdentifierCache[ext] = result
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
