// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// A file or directory on the server.
///
public struct NKFile: Sendable {
    public var account: String
    public var classFile: String
    public var commentsUnread: Bool
    public var contentType: String
    public var checksums: String
    public var creationDate: Date?
    public var dataFingerprint: String
    public var date: Date
    public var directory: Bool
    public var downloadURL: String

    ///
    /// Download limits for shares of this file.
    ///
    public var downloadLimits: [NKDownloadLimit]

    public var e2eEncrypted: Bool
    public var etag: String
    public var favorite: Bool
    public var fileId: String
    public var fileName: String
    public var hasPreview: Bool
    public var iconName: String
    public var mountType: String
    public var name: String
    public var note: String
    public var ocId: String
    public var ownerId: String
    public var ownerDisplayName: String
    public var lock: Bool
    public var lockOwner: String
    public var lockOwnerEditor: String
    public var lockOwnerType: Int
    public var lockOwnerDisplayName: String
    public var lockTime: Date?
    public var lockTimeOut: Date?
    public var path: String
    public var permissions: String
    public var quotaUsedBytes: Int64
    public var quotaAvailableBytes: Int64
    public var resourceType: String
    public var richWorkspace: String?
    public var sharePermissionsCollaborationServices: Int
    public var sharePermissionsCloudMesh: [String]
    public var shareType: [Int]
    public var size: Int64
    public var serverUrl: String
    public var tags: [String]
    public var trashbinFileName: String
    public var trashbinOriginalLocation: String
    public var trashbinDeletionTime: Date
    public var uploadDate: Date?
    public var urlBase: String
    public var user: String
    public var userId: String
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var height: Double
    public var width: Double
    public var hidden: Bool
    /// If this is not empty, the media is a live photo. New media gets this straight from server, but old media needs to be detected as live photo (look isFlaggedAsLivePhotoByServer)
    public var livePhotoFile: String
    /// Indicating if the file is sent as a live photo from the server, or if we should detect it as such and convert it client-side
    public var isFlaggedAsLivePhotoByServer: Bool
    ///
    public var datePhotosOriginal: Date?
    ///
    public struct ChildElement {
        let name: String
        let text: String?
    }
    public var exifPhotos: [[String: String?]]
    public var placePhotos: String?
    public var typeIdentifier: String

    public init(
        account: String = "",
        classFile: String = "",
        commentsUnread: Bool = false,
        contentType: String = "",
        checksums: String = "",
        creationDate: Date? = nil,
        dataFingerprint: String = "",
        date: Date = Date(),
        directory: Bool = false,
        downloadURL: String = "",
        downloadLimits: [NKDownloadLimit] = .init(),
        e2eEncrypted: Bool = false,
        etag: String = "",
        favorite: Bool = false,
        fileId: String = "",
        fileName: String = "",
        hasPreview: Bool = false,
        iconName: String = "",
        mountType: String = "",
        name: String = "",
        note: String = "",
        ocId: String = "",
        ownerId: String = "",
        ownerDisplayName: String = "",
        lock: Bool = false,
        lockOwner: String = "",
        lockOwnerEditor: String = "",
        lockOwnerType: Int = 0,
        lockOwnerDisplayName: String = "",
        lockTime: Date? = nil,
        lockTimeOut: Date? = nil,
        path: String = "",
        permissions: String = "",
        quotaUsedBytes: Int64 = 0,
        quotaAvailableBytes: Int64 = 0,
        resourceType: String = "",
        richWorkspace: String? = nil,
        sharePermissionsCollaborationServices: Int = 0,
        sharePermissionsCloudMesh: [String] = [],
        shareType: [Int] = [],
        size: Int64 = 0,
        serverUrl: String = "",
        tags: [String] = [],
        trashbinFileName: String = "",
        trashbinOriginalLocation: String = "",
        trashbinDeletionTime: Date = Date(),
        uploadDate: Date? = nil,
        urlBase: String = "",
        user: String = "",
        userId: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        altitude: Double = 0,
        height: Double = 0,
        width: Double = 0,
        hidden: Bool = false,
        livePhotoFile: String = "",
        isFlaggedAsLivePhotoByServer: Bool = false,
        datePhotosOriginal: Date? = nil,
        exifPhotos: [[String : String?]] = .init(),
        placePhotos: String? = nil,
        typeIdentifier: String = "") {

            self.account = account
            self.classFile = classFile
            self.commentsUnread = commentsUnread
            self.contentType = contentType
            self.checksums = checksums
            self.creationDate = creationDate
            self.dataFingerprint = dataFingerprint
            self.date = date
            self.directory = directory
            self.downloadURL = downloadURL
            self.downloadLimits = downloadLimits
            self.e2eEncrypted = e2eEncrypted
            self.etag = etag
            self.favorite = favorite
            self.fileId = fileId
            self.fileName = fileName
            self.hasPreview = hasPreview
            self.iconName = iconName
            self.mountType = mountType
            self.name = name
            self.note = note
            self.ocId = ocId
            self.ownerId = ownerId
            self.ownerDisplayName = ownerDisplayName
            self.lock = lock
            self.lockOwner = lockOwner
            self.lockOwnerEditor = lockOwnerEditor
            self.lockOwnerType = lockOwnerType
            self.lockOwnerDisplayName = lockOwnerDisplayName
            self.lockTime = lockTime
            self.lockTimeOut = lockTimeOut
            self.path = path
            self.permissions = permissions
            self.quotaUsedBytes = quotaUsedBytes
            self.quotaAvailableBytes = quotaAvailableBytes
            self.resourceType = resourceType
            self.richWorkspace = richWorkspace
            self.sharePermissionsCollaborationServices = sharePermissionsCollaborationServices
            self.sharePermissionsCloudMesh = sharePermissionsCloudMesh
            self.shareType = shareType
            self.size = size
            self.serverUrl = serverUrl
            self.tags = tags
            self.trashbinFileName = trashbinFileName
            self.trashbinOriginalLocation = trashbinOriginalLocation
            self.trashbinDeletionTime = trashbinDeletionTime
            self.uploadDate = uploadDate
            self.urlBase = urlBase
            self.user = user
            self.userId = userId
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            self.height = height
            self.width = width
            self.hidden = hidden
            self.livePhotoFile = livePhotoFile
            self.isFlaggedAsLivePhotoByServer = isFlaggedAsLivePhotoByServer
            self.datePhotosOriginal = datePhotosOriginal
            self.exifPhotos = exifPhotos
            self.placePhotos = placePhotos
            self.typeIdentifier = typeIdentifier
    }
}
