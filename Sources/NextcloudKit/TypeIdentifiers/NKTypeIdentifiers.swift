// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UniformTypeIdentifiers

/// Actor responsible for resolving file type metadata (UTI, MIME type, icon, class file, etc.) in a thread-safe manner.
public actor NKTypeIdentifiers {

    private var utiCache: [String: String] = [:]
    private var mimeTypeCache: [String: String] = [:]
    private var filePropertiesCache: [String: NKFileProperty] = [:]
    private let resolver = NKFilePropertyResolver()

    public init() {}

    /// Resolves internal type metadata for a given file.
    public func getInternalType(fileName: String, mimeType inputMimeType: String, directory: Bool, account: String) -> (mimeType: String,
                                                                                                                        classFile: String,
                                                                                                                        iconName: String,
                                                                                                                        typeIdentifier: String,
                                                                                                                        fileNameWithoutExt: String,
                                                                                                                        ext: String) {
        var ext = (fileName as NSString).pathExtension.lowercased()
        var mimeType = inputMimeType
        var classFile = ""
        var iconName = ""
        var typeIdentifier = ""
        var fileNameWithoutExt = ""
        var uti: String?

        // UTI cache
        if let cachedUTI = utiCache[ext] {
            uti = cachedUTI
        } else if let type = UTType(filenameExtension: ext) {
            utiCache[ext] = type.identifier
            uti = type.identifier
        }

        if let uti {
            typeIdentifier = uti as String
            fileNameWithoutExt = (fileName as NSString).deletingPathExtension

            // MIME type detection
            if mimeType.isEmpty {
                if let cachedMime = mimeTypeCache[typeIdentifier] {
                    mimeType = cachedMime
                } else if let type = UTType(typeIdentifier),
                          let resolvedMime = type.preferredMIMEType {
                    mimeType = resolvedMime
                    mimeTypeCache[typeIdentifier] = resolvedMime
                }
            }

            // Directory override
            if directory {
                mimeType = "httpd/unix-directory"
                classFile = NKTypeClassFile.directory.rawValue
                iconName = NKTypeIconFile.directory.rawValue
                typeIdentifier = UTType.folder.identifier
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

                classFile = fileProps.classFile.rawValue
                iconName = fileProps.iconName.rawValue
            }
        }

        return (mimeType: mimeType, classFile: classFile, iconName: iconName, typeIdentifier: typeIdentifier, fileNameWithoutExt: fileNameWithoutExt, ext: ext)
    }
}

public final class NKTypeIdentifiersHelper {
    private let actor: NKTypeIdentifiers

    public init(actor: NKTypeIdentifiers) {
        self.actor = actor
    }

    public func getInternalTypeSync(fileName: String, mimeType: String, directory: Bool, account: String) -> (mimeType: String,
                                                                                                              classFile: String,
                                                                                                              iconName: String,
                                                                                                              typeIdentifier: String,
                                                                                                              fileNameWithoutExt: String,
                                                                                                              ext: String) {
        var result: (mimeType: String,
                     classFile: String,
                     iconName: String,
                     typeIdentifier: String,
                     fileNameWithoutExt: String,
                     ext: String)!

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
        return result
    }
}
