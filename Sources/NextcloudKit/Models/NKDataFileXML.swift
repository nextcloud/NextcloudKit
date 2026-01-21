// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftyXMLParser

public class NKDataFileXML: NSObject {
    var nkCommonInstance: NKCommon
    let requestBodyComments =
    """
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:prop>
            <oc:id />
            <oc:verb />
            <oc:actorType />
            <oc:actorId />
            <oc:creationDateTime />
            <oc:objectType />
            <oc:objectId />
            <oc:isUnread />
            <oc:message />
            <oc:actorDisplayName />"
        </d:prop>
    </d:propfind>
    """

    let requestBodyCommentsMarkAsRead =
    """
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <d:propertyupdate xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:set>
            <d:prop>
                <readMarker xmlns=\"http://owncloud.org/ns\"/>
            </d:prop>
        </d:set>
    </d:propertyupdate>
    """

    let requestBodyCommentsUpdate =
    """
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <d:propertyupdate xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:set>
            <d:prop>
                <oc:message>%@</oc:message>
            </d:prop>
        </d:set>
    </d:propertyupdate>
    """

    public func getRequestBodyFile(createProperties: [NKProperties]?, removeProperties: [NKProperties] = []) -> String {
        let request = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop>
        """ + NKProperties.properties(createProperties: createProperties, removeProperties: removeProperties) + """
            </d:prop>
        </d:propfind>
        """
        return request
    }

    public func getRequestBodyFileExists() -> String {
        let request = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop>
                <d:getetag />
                <fileid xmlns=\"http://owncloud.org/ns\"/>
                <id xmlns=\"http://owncloud.org/ns\"/>
            </d:prop>
        </d:propfind>
        """
        return request
    }

    let requestBodyFileSetFavorite =
    """
    <?xml version=\"1.0\"?>
    <d:propertyupdate xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\">
        <d:set>
            <d:prop>
                <oc:favorite>%i</oc:favorite>
            </d:prop>
        </d:set>
    </d:propertyupdate>
    """

    func getRequestBodyFileListingFavorites(createProperties: [NKProperties]?, removeProperties: [NKProperties] = []) -> String {
        let request = """
        <?xml version=\"1.0\"?>
        <oc:filter-files xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop>
        """ + NKProperties.properties(createProperties: createProperties, removeProperties: removeProperties) + """
            </d:prop>
            <oc:filter-rules>
                <oc:favorite>1</oc:favorite>
            </oc:filter-rules>
        </oc:filter-files>
        """
        return request
    }

    func getRequestBodySearchFileName(createProperties: [NKProperties]?, removeProperties: [NKProperties] = []) -> String {
        let request = """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
            <d:select>
                <d:prop>
        """ + NKProperties.properties(createProperties: createProperties, removeProperties: removeProperties) + """
                </d:prop>
            </d:select>
            <d:from>
                <d:scope>
                    <d:href>%@</d:href>
                    <d:depth>%@</d:depth>
                </d:scope>
            </d:from>
            <d:where>
                <d:like>
                    <d:prop><d:displayname/></d:prop>
                    <d:literal>%@</d:literal>
                </d:like>
            </d:where>
        </d:basicsearch>
        </d:searchrequest>
        """
        return request
    }

    func getRequestBodySearchFileId(createProperties: [NKProperties]?, removeProperties: [NKProperties] = []) -> String {
        let request = """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
            <d:select>
                <d:prop>
        """ + NKProperties.properties(createProperties: createProperties, removeProperties: removeProperties) + """
                </d:prop>
            </d:select>
            <d:from>
                <d:scope>
                    <d:href>/files/%@</d:href>
                    <d:depth>infinity</d:depth>
                </d:scope>
            </d:from>
            <d:where>
                <d:eq>
                    <d:prop><oc:fileid xmlns:oc=\"http://owncloud.org/ns\"/></d:prop>
                    <d:literal>%@</d:literal>
                </d:eq>
            </d:where>
        </d:basicsearch>
        </d:searchrequest>
        """
        return request
    }

    func getRequestBodySearchMedia(createProperties: [NKProperties]?, removeProperties: [NKProperties] = []) -> String {
        let request = """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
        <d:select>
            <d:prop>
        """ + NKProperties.properties(createProperties: createProperties, removeProperties: removeProperties) + """
            </d:prop>
        </d:select>
            <d:from>
                <d:scope>
                    <d:href>%@</d:href>
                    <d:depth>infinity</d:depth>
                </d:scope>
            </d:from>
            <d:orderby>
                <d:order>
                    <d:prop><%@></d:prop>
                    <d:descending/>
                </d:order>
                <d:order>
                    <d:prop><d:displayname/></d:prop>
                    <d:descending/>
                </d:order>
            </d:orderby>
            <d:where>
                <d:and>
                <d:or>
                    <d:like>
                        <d:prop><d:getcontenttype/></d:prop>
                        <d:literal>image/%%</d:literal>
                    </d:like>
                    <d:like>
                        <d:prop><d:getcontenttype/></d:prop>
                        <d:literal>video/%%</d:literal>
                    </d:like>
                </d:or>
                <d:or>
                    <d:and>
                        <d:lt>
                            <d:prop><%@></d:prop>
                            <d:literal>%@</d:literal>
                        </d:lt>
                        <d:gt>
                            <d:prop><%@></d:prop>
                            <d:literal>%@</d:literal>
                        </d:gt>
                    </d:and>
                </d:or>
                </d:and>
            </d:where>
            <d:limit>
                <d:nresults>%@</d:nresults>
            </d:limit>
        </d:basicsearch>
        </d:searchrequest>
        """
        return request
    }

    let requestBodyTrash =
    """
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:prop>
    """ + NKProperties.trashProperties() + """
        </d:prop>
    </d:propfind>
    """

    let requestBodyLivephoto =
    """
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <d:propertyupdate xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:set>
            <d:prop>
                <nc:metadata-files-live-photo>%@</nc:metadata-files-live-photo>
            </d:prop>
        </d:set>
    </d:propertyupdate>
    """

    public init(nkCommonInstance: NKCommon) {
        self.nkCommonInstance = nkCommonInstance
        super.init()
    }

    func convertDataAppPassword(data: Data) -> String? {
        let xml = XML.parse(data)
        return xml["ocs", "data", "apppassword"].text
    }

    func convertDataFile(xmlData: Data, nkSession: NKSession, rootFileName: String, showHiddenFiles: Bool, includeHiddenFiles: [String]) async -> [NKFile] {
        var files: [NKFile] = []
        let rootFiles = "/" + nkSession.dav + "/files/"
        guard let baseUrl = self.nkCommonInstance.getHostName(urlString: nkSession.urlBase) else {
            return files
        }
        let xml = XML.parse(xmlData)
        let elements = xml["d:multistatus", "d:response"]

        for element in elements {
            var file = NKFile()
            if let href = element["d:href"].text {
                var fileNamePath = href
                if href.last == "/" {
                    fileNamePath = String(href.dropLast())
                }

                // Hidden File/Directory/Sub of directoty
                if !showHiddenFiles {
                    let componentsPath = (href as NSString).pathComponents
                    let componentsFiltered = componentsPath.filter { $0.hasPrefix(".") }
                    if includeHiddenFiles.isEmpty {
                        if !componentsFiltered.isEmpty {
                            continue
                        }
                    } else {
                        let includeHiddenFilesFilter = componentsPath.filter { includeHiddenFiles.contains($0) }
                        if includeHiddenFilesFilter.isEmpty && !componentsFiltered.isEmpty {
                            continue
                        }
                    }
                }

                // account
                file.account = nkSession.account

                // path
                file.path = (fileNamePath as NSString).deletingLastPathComponent + "/"
                file.path = file.path.removingPercentEncoding ?? ""

                // fileName
                file.fileName = (fileNamePath as NSString).lastPathComponent
                file.fileName = file.fileName.removingPercentEncoding ?? ""

                // ServerUrl
                if href == rootFiles + nkSession.user + "/" {
                    file.fileName = rootFileName
                    file.serverUrl = baseUrl + rootFiles + nkSession.user
                } else {
                    file.serverUrl = baseUrl + file.path.dropLast()
                }
            }

            let propstat = element["d:propstat"][0]

            if let getlastmodified = propstat["d:prop", "d:getlastmodified"].text,
               let date = getlastmodified.parsedDate(using: "EEE, dd MMM y HH:mm:ss zzz") { 
                file.date = date
            }

            if let creationtime = propstat["d:prop", "nc:creation_time"].double, creationtime > 0 {
                file.creationDate = Date(timeIntervalSince1970: creationtime)
            }

            if let uploadtime = propstat["d:prop", "nc:upload_time"].double, uploadtime > 0 {
                file.uploadDate = Date(timeIntervalSince1970: uploadtime)
            }

            if let getetag = propstat["d:prop", "d:getetag"].text {
                file.etag = getetag.replacingOccurrences(of: "\"", with: "")
            }

            if let getcontenttype = propstat["d:prop", "d:getcontenttype"].text {
                file.contentType = getcontenttype
            }

            if let dataFingerprint = propstat["d:prop", "d:data-fingerprint"].text {
                file.dataFingerprint = dataFingerprint
            }

            if let downloadURL = propstat["d:prop", "d:downloadURL"].text {
                file.downloadURL = downloadURL
            }

            if let note = propstat["d:prop", "nc:note"].text {
                file.note = note
            }

            if let sharePermissionsCollaborationServices = propstat["d:prop", "x1:share-permissions"].int {
                file.sharePermissionsCollaborationServices = sharePermissionsCollaborationServices
            }

            if let sharePermissionsCloudMesh = propstat["d:prop", "x2:share-permissions"].text {
                let elements = sharePermissionsCloudMesh.components(separatedBy: ",")
                for element in elements {
                    let result = (element as String).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").replacingOccurrences(of: "\"", with: "")
                    file.sharePermissionsCloudMesh.append(result)
                }
            }

            if let checksums = propstat["d:prop", "d:checksums"].text {
                file.checksums = checksums
            }

            let resourcetypeElement = propstat["d:prop", "d:resourcetype"]
            if resourcetypeElement["d:collection"].error == nil {
                file.directory = true
                file.contentType = "httpd/unix-directory"
            } else {
                if let resourcetype = propstat["d:prop", "d:resourcetype"].text {
                    file.resourceType = resourcetype
                }
            }

            if let quotaavailablebytes = propstat["d:prop", "d:quota-available-bytes"].text {
                file.quotaAvailableBytes = Int64(quotaavailablebytes) ?? 0
            }

            if let quotausedbytes = propstat["d:prop", "d:quota-used-bytes"].text {
                file.quotaUsedBytes = Int64(quotausedbytes) ?? 0
            }

            if let permissions = propstat["d:prop", "oc:permissions"].text {
                file.permissions = permissions
            }

            if let ocId = propstat["d:prop", "oc:id"].text {
                file.ocId = ocId
            }

            if let fileId = propstat["d:prop", "oc:fileid"].text {
                file.fileId = fileId
            }

            if let size = propstat["d:prop", "oc:size"].text {
                file.size = Int64(size) ?? 0
            }

            for shareTypesElement in propstat["d:prop", "oc:share-types"] {
                if let shareTypes = shareTypesElement["oc:share-type"].int {
                    file.shareType.append(shareTypes)
                }
            }

            if let favorite = propstat["d:prop", "oc:favorite"].text {
                file.favorite = (favorite as NSString).boolValue
            }

            if let ownerid = propstat["d:prop", "oc:owner-id"].text {
                file.ownerId = ownerid
            }

            if let ownerdisplayname = propstat["d:prop", "oc:owner-display-name"].text {
                file.ownerDisplayName = ownerdisplayname
            }

            if let commentsunread = propstat["d:prop", "oc:comments-unread"].text {
                file.commentsUnread = (commentsunread as NSString).boolValue
            }

            if let encrypted = propstat["d:prop", "nc:is-encrypted"].text {
                file.e2eEncrypted = (encrypted as NSString).boolValue
            }

            if let haspreview = propstat["d:prop", "nc:has-preview"].text {
                file.hasPreview = (haspreview as NSString).boolValue
            }

            if let mounttype = propstat["d:prop", "nc:mount-type"].text {
                file.mountType = mounttype
            }

            if let richWorkspace = propstat["d:prop", "nc:rich-workspace"].text {
                file.richWorkspace = richWorkspace
            }

            if let lock = propstat["d:prop", "nc:lock"].int {
                file.lock = lock > 0
            }

            if let lockOwner = propstat["d:prop", "nc:lock-owner"].text {
                file.lockOwner = lockOwner
            }
            if let lockOwnerEditor = propstat["d:prop", "nc:lock-owner-editor"].text {
                file.lockOwnerEditor = lockOwnerEditor
            }
            if let lockOwnerType = propstat["d:prop", "nc:lock-owner-type"].int {
                file.lockOwnerType = lockOwnerType
            }
            if let lockOwnerDisplayName = propstat["d:prop", "nc:lock-owner-displayname"].text {
                file.lockOwnerDisplayName = lockOwnerDisplayName
            }
            if let lockTime = propstat["d:prop", "nc:lock-time"].int {
                file.lockTime = Date(timeIntervalSince1970: TimeInterval(lockTime))
            }
            if let lockTimeOut = propstat["d:prop", "nc:lock-timeout"].int {
                file.lockTimeOut = file.lockTime?.addingTimeInterval(TimeInterval(lockTimeOut))
            }

            let tagsElements = propstat["d:prop", "nc:system-tags"]
            for element in tagsElements["nc:system-tag"] {
                guard let tag = element.text else { continue }
                file.tags.append(tag)
            }

            // NC27 -----
            if let latitude = propstat["d:prop", "nc:file-metadata-gps", "latitude"].double {
                file.latitude = latitude
            }
            if let longitude = propstat["d:prop", "nc:file-metadata-gps", "longitude"].double {
                file.longitude = longitude
            }
            if let altitude = propstat["d:prop", "nc:file-metadata-gps", "altitude"].double {
                file.altitude = altitude
            }

            if let width = propstat["d:prop", "nc:file-metadata-size", "width"].double {
                file.width = width
            }
            if let height = propstat["d:prop", "nc:file-metadata-size", "height"].double {
                file.height = height
            }
            // ----------

            // ----- NC28
            if let latitude = propstat["d:prop", "nc:metadata-photos-gps", "latitude"].double {
                file.latitude = latitude
            }
            if let longitude = propstat["d:prop", "nc:metadata-photos-gps", "longitude"].double {
                file.longitude = longitude
            }
            if let altitude = propstat["d:prop", "nc:metadata-photos-gps", "altitude"].double {
                file.altitude = altitude
            }

            if let width = propstat["d:prop", "nc:metadata-photos-size", "width"].double {
                file.width = width
            }
            if let height = propstat["d:prop", "nc:metadata-photos-size", "height"].double {
                file.height = height
            }
            // ----------

            if let livePhotoFile = propstat["d:prop", "nc:metadata-files-live-photo"].text {
                file.livePhotoFile = livePhotoFile
                file.isFlaggedAsLivePhotoByServer = true
            }

            if let hidden = propstat["d:prop", "nc:hidden"].text {
                file.hidden = (hidden as NSString).boolValue
            }

            if let datePhotosOriginal = propstat["d:prop", "nc:metadata-photos-original_date_time"].double, datePhotosOriginal > 0 {
                file.datePhotosOriginal = Date(timeIntervalSince1970: datePhotosOriginal)
            }

            let exifPhotosElements = propstat["d:prop", "nc:metadata-photos-exif"]
            if let element = exifPhotosElements.element {
                for child in element.childElements {
                    file.exifPhotos.append([child.name: child.text])
                }
            }

            file.placePhotos = propstat["d:prop", "nc:metadata-photos-place"].text

            for downloadLimit in propstat["d:prop", "nc:share-download-limits", "nc:share-download-limit"] {
                guard let token = downloadLimit["nc:token"].text else {
                    continue
                }

                guard let limit = downloadLimit["nc:limit"].int else {
                    continue
                }

                guard let count = downloadLimit["nc:count"].int else {
                    continue
                }

                file.downloadLimits.append(NKDownloadLimit(count: count, limit: limit, token: token))
            }

            let results = await self.nkCommonInstance.typeIdentifiers.getInternalType(fileName: file.fileName, mimeType: file.contentType, directory: file.directory, account: nkSession.account)

            file.contentType = results.mimeType
            file.iconName = results.iconName
            file.name = "files"
            file.classFile = results.classFile
            file.typeIdentifier = results.typeIdentifier

            file.urlBase = nkSession.urlBase
            file.user = nkSession.user
            file.userId = nkSession.userId

            files.append(file)
        }

        // Live photo detect
        files = files.sorted {
            return ($0.serverUrl, ($0.fileName as NSString).deletingPathExtension, $0.classFile) < ($1.serverUrl, ($1.fileName as NSString).deletingPathExtension, $1.classFile)
        }
        for index in files.indices {
            if !files[index].livePhotoFile.isEmpty || files[index].directory {
                continue
            }
            if index < files.count - 1,
               (files[index].fileName as NSString).deletingPathExtension == (files[index + 1].fileName as NSString) .deletingPathExtension,
               files[index].classFile == NKTypeClassFile.image.rawValue,
               files[index + 1].classFile == NKTypeClassFile.video.rawValue {
                files[index].livePhotoFile = files[index + 1].fileId
                files[index + 1].livePhotoFile = files[index].fileId
            }
        }

        return files
    }

    func convertDataTrash(xmlData: Data, nkSession: NKSession, showHiddenFiles: Bool) async -> [NKTrash] {
        var files: [NKTrash] = []
        var first: Bool = true
        guard let baseUrl = self.nkCommonInstance.getHostName(urlString: nkSession.urlBase) else {
            return files
        }
        let xml = XML.parse(xmlData)
        let elements = xml["d:multistatus", "d:response"]

        for element in elements {
            if first {
                first = false
                continue
            }
            var file = NKTrash()
            if let href = element["d:href"].text {
                var fileNamePath = href

                if href.last == "/" {
                    fileNamePath = String(href.dropLast())
                }

                // path
                file.filePath = (fileNamePath as NSString).deletingLastPathComponent + "/"
                file.filePath = file.filePath.removingPercentEncoding ?? ""
                file.filePath = baseUrl + file.filePath

                // fileName
                file.fileName = (fileNamePath as NSString).lastPathComponent
                file.fileName = file.fileName.removingPercentEncoding ?? ""
            }

            let propstat = element["d:propstat"][0]

            if let getlastmodified = propstat["d:prop", "d:getlastmodified"].text,
               let date = getlastmodified.parsedDate(using: "EEE, dd MMM y HH:mm:ss zzz") {
                file.date = date
            }

            if let getcontenttype = propstat["d:prop", "d:getcontenttype"].text {
                file.contentType = getcontenttype
            }

            let resourcetypeElement = propstat["d:prop", "d:resourcetype"]
            if resourcetypeElement["d:collection"].error == nil {
                file.directory = true
                file.contentType = "httpd/unix-directory"
            }

            if let ocId = propstat["d:prop", "oc:id"].text {
                file.ocId = ocId
            }

            if let fileId = propstat["d:prop", "oc:fileid"].text {
                file.fileId = fileId
            }

            if let haspreview = propstat["d:prop", "nc:has-preview"].text {
                file.hasPreview = (haspreview as NSString).boolValue
            }

            if let size = propstat["d:prop", "oc:size"].text {
                file.size = Int64(size) ?? 0
            }

            if let trashbinFileName = propstat["d:prop", "nc:trashbin-filename"].text {
                file.trashbinFileName = trashbinFileName
            }

            if let trashbinOriginalLocation = propstat["d:prop", "nc:trashbin-original-location"].text {
                file.trashbinOriginalLocation = trashbinOriginalLocation
            }

            if let trashbinDeletionTime = propstat["d:prop", "nc:trashbin-deletion-time"].text, let trashbinDeletionTimeDouble = Double(trashbinDeletionTime) {
                file.trashbinDeletionTime = Date(timeIntervalSince1970: trashbinDeletionTimeDouble)
            }

            let results = await self.nkCommonInstance.typeIdentifiers.getInternalType(fileName: file.trashbinFileName, mimeType: file.contentType, directory: file.directory, account: nkSession.account)

            file.contentType = results.mimeType
            file.classFile = results.classFile
            file.iconName = results.iconName
            file.typeIdentifier = results.typeIdentifier

            files.append(file)
        }

        return files
    }

    func convertDataComments(xmlData: Data) -> [NKComments] {
        var items: [NKComments] = []
        let xml = XML.parse(xmlData)
        let elements = xml["d:multistatus", "d:response"]

        for element in elements {
            let item = NKComments()

            if let value = element["d:href"].text {
                item.path = value
            }

            if let value = element["d:propstat", "d:prop", "oc:actorDisplayName"].text {
                item.actorDisplayName = value
            }

            if let value = element["d:propstat", "d:prop", "oc:actorId"].text {
                item.actorId = value
            }

            if let value = element["d:propstat", "d:prop", "oc:actorType"].text {
                item.actorType = value
            }

            if let creationDateTime = element["d:propstat", "d:prop", "oc:creationDateTime"].text,
               let date = creationDateTime.parsedDate(using: "EEE, dd MMM y HH:mm:ss zzz") {
                item.creationDateTime = date
            }

            if let value = element["d:propstat", "d:prop", "oc:isUnread"].text {
                item.isUnread = (value as NSString).boolValue
            }

            if let value = element["d:propstat", "d:prop", "oc:message"].text {
                item.message = value
            }

            if let value = element["d:propstat", "d:prop", "oc:id"].text {
                item.messageId = value
            }

            if let value = element["d:propstat", "d:prop", "oc:objectId"].text {
                item.objectId = value
            }

            if let value = element["d:propstat", "d:prop", "oc:objectType"].text {
                item.objectType = value
            }

            if let value = element["d:propstat", "d:prop", "oc:verb"].text {
                item.verb = value
            }

            if let value = element["d:propstat", "d:status"].text, value.contains("200") {
                items.append(item)
            }
        }

        return items
    }
}
