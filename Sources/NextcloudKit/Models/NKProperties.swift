// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// Definition of properties used for decoding in ``NKDataFileXML``.
///
public enum NKProperties: String, CaseIterable {
    /// DAV
    case displayname = "<d:displayname />"

    ///
    /// Download limits for shares of a file as optionally provided by the [Files Download Limit](https://github.com/nextcloud/files_downloadlimit) app for Nextcloud server.
    ///
    case downloadLimit = "<nc:share-download-limits />"

    case getlastmodified = "<d:getlastmodified />"
    case getetag = "<d:getetag />"
    case getcontenttype = "<d:getcontenttype />"
    case resourcetype = "<d:resourcetype />"
    case quotaavailablebytes = "<d:quota-available-bytes />"
    case quotausedbytes = "<d:quota-used-bytes />"
    case getcontentlength = "<d:getcontentlength />"
    /// owncloud.org
    case permissions = "<permissions xmlns=\"http://owncloud.org/ns\"/>"
    case id = "<id xmlns=\"http://owncloud.org/ns\"/>"
    case fileid = "<fileid xmlns=\"http://owncloud.org/ns\"/>"
    case size = "<size xmlns=\"http://owncloud.org/ns\"/>"
    case favorite = "<favorite xmlns=\"http://owncloud.org/ns\"/>"
    case sharetypes = "<share-types xmlns=\"http://owncloud.org/ns\"/>"
    case ownerid = "<owner-id xmlns=\"http://owncloud.org/ns\"/>"
    case ownerdisplayname = "<owner-display-name xmlns=\"http://owncloud.org/ns\"/>"
    case commentsunread = "<comments-unread xmlns=\"http://owncloud.org/ns\"/>"
    case checksums = "<checksums xmlns=\"http://owncloud.org/ns\"/>"
    case downloadURL = "<downloadURL xmlns=\"http://owncloud.org/ns\"/>"
    case datafingerprint = "<data-fingerprint xmlns=\"http://owncloud.org/ns\"/>"
    /// nextcloud.org
    case creationtime = "<creation_time xmlns=\"http://nextcloud.org/ns\"/>"
    case uploadtime = "<upload_time xmlns=\"http://nextcloud.org/ns\"/>"
    case isencrypted = "<is-encrypted xmlns=\"http://nextcloud.org/ns\"/>"
    case haspreview = "<has-preview xmlns=\"http://nextcloud.org/ns\"/>"
    case mounttype = "<mount-type xmlns=\"http://nextcloud.org/ns\"/>"
    case richworkspace = "<rich-workspace xmlns=\"http://nextcloud.org/ns\"/>"
    case note = "<note xmlns=\"http://nextcloud.org/ns\"/>"
    case lock = "<lock xmlns=\"http://nextcloud.org/ns\"/>"
    case lockowner = "<lock-owner xmlns=\"http://nextcloud.org/ns\"/>"
    case lockownereditor = "<lock-owner-editor xmlns=\"http://nextcloud.org/ns\"/>"
    case lockownerdisplayname = "<lock-owner-displayname xmlns=\"http://nextcloud.org/ns\"/>"
    case lockownertype = "<lock-owner-type xmlns=\"http://nextcloud.org/ns\"/>"
    case locktime = "<lock-time xmlns=\"http://nextcloud.org/ns\"/>"
    case locktimeout = "<lock-timeout xmlns=\"http://nextcloud.org/ns\"/>"
    case systemtags = "<system-tags xmlns=\"http://nextcloud.org/ns\"/>"
    case filemetadatasize = "<file-metadata-size xmlns=\"http://nextcloud.org/ns\"/>"
    case filemetadatagps = "<file-metadata-gps xmlns=\"http://nextcloud.org/ns\"/>"
    case metadataphotosexif = "<metadata-photos-exif xmlns=\"http://nextcloud.org/ns\"/>"
    case metadataphotosgps = "<metadata-photos-gps xmlns=\"http://nextcloud.org/ns\"/>"
    case metadataphotosoriginaldatetime = "<metadata-photos-original_date_time xmlns=\"http://nextcloud.org/ns\"/>"
    case metadataphotoplace = "<metadata-photos-place xmlns=\"http://nextcloud.org/ns\"/>"
    case metadataphotossize = "<metadata-photos-size xmlns=\"http://nextcloud.org/ns\"/>"
    case metadatafileslivephoto = "<metadata-files-live-photo xmlns=\"http://nextcloud.org/ns\"/>"
    case hidden = "<hidden xmlns=\"http://nextcloud.org/ns\"/>"
    /// open-collaboration-services.org
    case sharepermissionscollaboration = "<share-permissions xmlns=\"http://open-collaboration-services.org/ns\"/>"
    /// open-cloud-mesh.org
    case sharepermissionscloudmesh = "<share-permissions xmlns=\"http://open-cloud-mesh.org/ns\"/>"

    static public func properties(createProperties: [NKProperties]?, removeProperties: [NKProperties] = []) -> String {
        var properties = allCases.map { $0.rawValue }.joined()
        if let createProperties {
            properties = ""
            properties = createProperties.map { $0.rawValue }.joined(separator: "")
        }
        for removeProperty in removeProperties {
            properties = properties.replacingOccurrences(of: removeProperty.rawValue, with: "")
        }
        return properties
    }

    static func trashProperties() -> String {
        let properties: [String] = [displayname.rawValue, getcontenttype.rawValue, resourcetype.rawValue, id.rawValue, fileid.rawValue, size.rawValue, haspreview.rawValue, "<trashbin-filename xmlns=\"http://nextcloud.org/ns\"/>", "<trashbin-original-location xmlns=\"http://nextcloud.org/ns\"/>", "<trashbin-deletion-time xmlns=\"http://nextcloud.org/ns\"/>"]
        return properties.joined()
    }
}
