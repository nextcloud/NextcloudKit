// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

/// Resolved file type metadata, used for cache and classification.
public struct NKTypeIdentifierCache: Sendable {
    public let mimeType: String
    public let classFile: String
    public let iconName: String
    public let typeIdentifier: String
    public let fileNameWithoutExt: String
    public let ext: String
}

/// Actor responsible for resolving file type metadata
/// (UTType, MIME type, icon, class file, etc.).
public actor NKTypeIdentifiers {

    public static let shared = NKTypeIdentifiers()

    // Cache key:
    // "<mimeType>|<extension>"
    private var filePropertyCache: [String: NKTypeIdentifierCache] = [:]

    // Internal resolver
    private let resolver = NKFilePropertyResolver()

    private init() {}

    // MARK: - Public

    /// Resolves internal file type information.
    ///
    /// MIME type is considered the primary source of truth.
    ///
    /// - Parameters:
    ///   - fileName: Original file name.
    ///   - inputMimeType: MIME type provided by backend/server.
    ///   - directory: Indicates whether the item is a directory.
    ///   - account: Current account identifier.
    ///
    /// - Returns: Fully resolved file type metadata.
    public func getInternalType(
        fileName: String,
        mimeType inputMimeType: String,
        directory: Bool,
        account: String
    ) async -> NKTypeIdentifierCache {

        var fileExtension =
            (fileName as NSString)
            .pathExtension
            .lowercased()

        let fileNameWithoutExtension =
            fileExtension.isEmpty
            ? fileName
            : (fileName as NSString).deletingPathExtension

        // MARK: - Directory special case

        if directory {

            return NKTypeIdentifierCache(
                mimeType: "httpd/unix-directory",
                classFile: NKTypeClassFile.directory.rawValue,
                iconName: NKTypeIconFile.directory.rawValue,
                typeIdentifier: UTType.folder.identifier,
                fileNameWithoutExt: fileName,
                ext: ""
            )
        }

        // MARK: - Resolve MIME type

        let resolvedMimeType: String

        if !inputMimeType.isEmpty {

            resolvedMimeType = inputMimeType

        } else if let mime =
                    UTType(filenameExtension: fileExtension)?
                    .preferredMIMEType {

            resolvedMimeType = mime

        } else {

            resolvedMimeType = "application/octet-stream"
        }

        // MARK: - Cache

        let cacheKey = "\(resolvedMimeType)|\(fileExtension)"

        if let cached = filePropertyCache[cacheKey] {
            return cached
        }

        // MARK: - Resolve UTType

        // Resolve from MIME type first.
        // Fallback to extension if needed.
        let resolvedType =
            UTType(mimeType: resolvedMimeType) ??
            UTType(filenameExtension: fileExtension) ??
            .data

        let typeIdentifier = resolvedType.identifier

        // Fill extension if missing
        if fileExtension.isEmpty {
            fileExtension =
                resolvedType.preferredFilenameExtension ??
                ""
        }

        // MARK: - Resolve properties

        let capabilities =
            await NKCapabilities.shared.getCapabilities(for: account)

        let properties = resolver.resolve(
            mimeType: resolvedMimeType,
            fileExtension: fileExtension,
            typeIdentifier: typeIdentifier,
            capabilities: capabilities
        )

        // MARK: - Result

        let result = NKTypeIdentifierCache(
            mimeType: resolvedMimeType,
            classFile: properties.classFile.rawValue,
            iconName: properties.iconName.rawValue,
            typeIdentifier: typeIdentifier,
            fileNameWithoutExt: fileNameWithoutExtension,
            ext: fileExtension
        )

        // Cache result
        filePropertyCache[cacheKey] = result

        return result
    }

    // MARK: - Cache

    /// Clears the internal cache.
    public func clearCache() {
        filePropertyCache.removeAll()
    }
}

/// Helper class used to access NKTypeIdentifiers
/// from synchronous contexts (legacy code, libraries, etc.).
public final class NKTypeIdentifiersHelper {

    public static let shared = NKTypeIdentifiersHelper()

    private let resolver = NKFilePropertyResolver()

    private init() {}

    // MARK: - Public

    /// Resolves internal type information synchronously.
    ///
    /// MIME type is considered the primary source of truth.
    ///
    /// - Parameters:
    ///   - fileName: Original file name.
    ///   - inputMimeType: MIME type provided by backend/server.
    ///   - directory: Indicates whether the item is a directory.
    ///   - capabilities: Current server capabilities.
    ///
    /// - Returns: Fully resolved file type metadata.
    public func getInternalType(
        fileName: String,
        mimeType inputMimeType: String,
        directory: Bool,
        capabilities: NKCapabilities.Capabilities
    ) -> NKTypeIdentifierCache {

        var fileExtension =
            (fileName as NSString)
            .pathExtension
            .lowercased()

        let fileNameWithoutExtension =
            fileExtension.isEmpty
            ? fileName
            : (fileName as NSString).deletingPathExtension

        // MARK: - Directory special case

        if directory {

            return NKTypeIdentifierCache(
                mimeType: "httpd/unix-directory",
                classFile: NKTypeClassFile.directory.rawValue,
                iconName: NKTypeIconFile.directory.rawValue,
                typeIdentifier: UTType.folder.identifier,
                fileNameWithoutExt: fileName,
                ext: ""
            )
        }

        // MARK: - Resolve MIME type

        let resolvedMimeType: String

        if !inputMimeType.isEmpty {

            resolvedMimeType = inputMimeType

        } else if let mime =
                    UTType(filenameExtension: fileExtension)?
                    .preferredMIMEType {

            resolvedMimeType = mime

        } else {

            resolvedMimeType = "application/octet-stream"
        }

        // MARK: - Resolve UTType

        let resolvedType =
            UTType(mimeType: resolvedMimeType) ??
            UTType(filenameExtension: fileExtension) ??
            .data

        let typeIdentifier = resolvedType.identifier

        // Fill extension if missing
        if fileExtension.isEmpty {
            fileExtension =
                resolvedType.preferredFilenameExtension ??
                ""
        }

        // MARK: - Resolve properties

        let properties = resolver.resolve(
            mimeType: resolvedMimeType,
            fileExtension: fileExtension,
            typeIdentifier: typeIdentifier,
            capabilities: capabilities
        )

        // MARK: - Result

        return NKTypeIdentifierCache(
            mimeType: resolvedMimeType,
            classFile: properties.classFile.rawValue,
            iconName: properties.iconName.rawValue,
            typeIdentifier: typeIdentifier,
            fileNameWithoutExt: fileNameWithoutExtension,
            ext: fileExtension
        )
    }
}
