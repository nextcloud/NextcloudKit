// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

/// Resolved file type metadata, used for cache and classification
public struct NKTypeIdentifierCache: Sendable {
    public let mimeType: String
    public let classFile: String
    public let iconName: String
    public let typeIdentifier: String
    public let fileNameWithoutExt: String
    public let ext: String
}

/// Actor responsible for resolving file type metadata (UTI, MIME type, icon, class file, etc.)
public actor NKTypeIdentifiers {
    public static let shared = NKTypeIdentifiers()
    // Cache: extension → resolved type info
    private var filePropertyCache: [String: NKTypeIdentifierCache] = [:]
    // Internal resolver
    private let resolver = NKFilePropertyResolver()

    private init() {}

    // Resolves type info from file name and optional MIME type
    public func getInternalType(fileName: String, mimeType inputMimeType: String, directory: Bool, account: String) -> NKTypeIdentifierCache {

        var ext = (fileName as NSString).pathExtension.lowercased()
        var mimeType = inputMimeType
        var classFile = ""
        var iconName = ""
        var typeIdentifier = ""
        var fileNameWithoutExt = (fileName as NSString).deletingPathExtension

        // Use full name if no extension
        if ext.isEmpty {
            fileNameWithoutExt = fileName
        }

        // Check cache first
        if let cached = filePropertyCache[ext] {
            return cached
        }

        // Resolve UTType
        let type = UTType(filenameExtension: ext) ?? .data
        typeIdentifier = type.identifier

        // Resolve MIME type
        if mimeType.isEmpty {
            mimeType = type.preferredMIMEType ?? "application/octet-stream"
        }

        // Handle folder case
        if directory {
            mimeType = "httpd/unix-directory"
            classFile = NKTypeClassFile.directory.rawValue
            iconName = NKTypeIconFile.directory.rawValue
            typeIdentifier = UTType.folder.identifier
            fileNameWithoutExt = fileName
            ext = ""
        } else {
            let props = resolver.resolve(inUTI: typeIdentifier, account: account)
            classFile = props.classFile.rawValue
            iconName = props.iconName.rawValue
        }

        // Construct result
        let result = NKTypeIdentifierCache(
            mimeType: mimeType,
            classFile: classFile,
            iconName: iconName,
            typeIdentifier: typeIdentifier,
            fileNameWithoutExt: fileNameWithoutExt,
            ext: ext
        )

        // Cache it
        if !ext.isEmpty {
            filePropertyCache[ext] = result
        }

        return result
    }

    // Clears the internal cache (used for testing or reset)
    public func clearCache() {
        filePropertyCache.removeAll()
    }
}

/// Helper class to access NKTypeIdentifiers from sync contexts (e.g. in legacy code or libraries).
public final class NKTypeIdentifiersHelper {
    public static let shared = NKTypeIdentifiersHelper()

    // Internal actor reference (uses NKTypeIdentifiers.shared by default)
    private let actor: NKTypeIdentifiers

    private init() {
        self.actor = .shared
    }

    // Init with optional custom actor (useful for testing)
    public init(actor: NKTypeIdentifiers = .shared) {
        self.actor = actor
    }

    // Synchronously resolves file type info by calling the async actor inside a semaphore block.
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
