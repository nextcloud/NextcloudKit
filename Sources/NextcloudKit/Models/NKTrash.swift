// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Representation of a trashed item.
///
public struct NKTrash: Sendable {
    public var ocId: String
    public var contentType: String
    public var typeIdentifier: String
    public var date: Date
    public var directory: Bool
    public var fileId: String
    public var fileName: String
    public var filePath: String
    public var hasPreview: Bool
    public var iconName: String
    public var size: Int64
    public var classFile: String
    public var trashbinFileName: String
    public var trashbinOriginalLocation: String
    public var trashbinDeletionTime: Date

    public init(ocId: String = "", contentType: String = "", typeIdentifier: String = "", date: Date = Date(), directory: Bool = false, fileId: String = "", fileName: String = "", filePath: String = "", hasPreview: Bool = false, iconName: String = "", size: Int64 = 0, classFile: String = "", trashbinFileName: String = "", trashbinOriginalLocation: String = "", trashbinDeletionTime: Date = Date()) {
        self.ocId = ocId
        self.contentType = contentType
        self.typeIdentifier = typeIdentifier
        self.date = date
        self.directory = directory
        self.fileId = fileId
        self.fileName = fileName
        self.filePath = filePath
        self.hasPreview = hasPreview
        self.iconName = iconName
        self.size = size
        self.classFile = classFile
        self.trashbinFileName = trashbinFileName
        self.trashbinOriginalLocation = trashbinOriginalLocation
        self.trashbinDeletionTime = trashbinDeletionTime
    }
}
