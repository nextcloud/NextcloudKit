// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKFile: NSObject {
    public var account = ""
    public var classFile = ""
    public var commentsUnread: Bool = false
    public var contentType = ""
    public var checksums = ""
    public var creationDate: Date?
    public var dataFingerprint = ""
    public var date = Date()
    public var directory: Bool = false
    public var downloadURL = ""
    public var e2eEncrypted: Bool = false
    public var etag = ""
    public var favorite: Bool = false
    public var fileId = ""
    public var fileName = ""
    public var hasPreview: Bool = false
    public var iconName = ""
    public var mountType = ""
    public var name = ""
    public var note = ""
    public var ocId = ""
    public var ownerId = ""
    public var ownerDisplayName = ""
    public var lock = false
    public var lockOwner = ""
    public var lockOwnerEditor = ""
    public var lockOwnerType = 0
    public var lockOwnerDisplayName = ""
    public var lockTime: Date?
    public var lockTimeOut: Date?
    public var path = ""
    public var permissions = ""
    public var quotaUsedBytes: Int64 = 0
    public var quotaAvailableBytes: Int64 = 0
    public var resourceType = ""
    public var richWorkspace: String?
    public var sharePermissionsCollaborationServices: Int = 0
    public var sharePermissionsCloudMesh: [String] = []
    public var shareType: [Int] = []
    public var size: Int64 = 0
    public var serverUrl = ""
    public var tags: [String] = []
    public var trashbinFileName = ""
    public var trashbinOriginalLocation = ""
    public var trashbinDeletionTime = Date()
    public var uploadDate: Date?
    public var urlBase = ""
    public var user = ""
    public var userId = ""
    public var latitude: Double = 0
    public var longitude: Double = 0
    public var altitude: Double = 0
    public var height: Double = 0
    public var width: Double = 0
    public var hidden = false
    /// If this is not empty, the media is a live photo. New media gets this straight from server, but old media needs to be detected as live photo (look isFlaggedAsLivePhotoByServer)
    public var livePhotoFile = ""
    /// Indicating if the file is sent as a live photo from the server, or if we should detect it as such and convert it client-side
    public var isFlaggedAsLivePhotoByServer = false
    ///
    public var datePhotosOriginal: Date?
    ///
    public struct ChildElement {
        let name: String
        let text: String?
    }
    public var exifPhotos = [[String: String?]]()
    public var placePhotos: String?
}
