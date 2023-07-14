//
//  NKModel.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 12/10/19.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

#if os(iOS)
import MobileCoreServices
#endif

import SwiftyXMLParser
import SwiftyJSON

// MARK: -

@objc public class NKActivity: NSObject {

    @objc public var app = ""
    @objc public var date = NSDate()
    @objc public var idActivity: Int = 0
    @objc public var icon = ""
    @objc public var link = ""
    @objc public var message = ""
    @objc public var messageRich: Data?
    @objc public var objectId: Int = 0
    @objc public var objectName = ""
    @objc public var objectType = ""
    @objc public var previews: Data?
    @objc public var subject = ""
    @objc public var subjectRich: Data?
    @objc public var type = ""
    @objc public var user = ""
}

@objc public class NKComments: NSObject {

    @objc public var actorDisplayName = ""
    @objc public var actorId = ""
    @objc public var actorType = ""
    @objc public var creationDateTime = NSDate()
    @objc public var isUnread: Bool = false
    @objc public var message = ""
    @objc public var messageId = ""
    @objc public var objectId = ""
    @objc public var objectType = ""
    @objc public var path = ""
    @objc public var verb = ""
}

@objc public class NKEditorDetailsCreators: NSObject {

    @objc public var editor = ""
    @objc public var ext = ""
    @objc public var identifier = ""
    @objc public var mimetype = ""
    @objc public var name = ""
    @objc public var templates: Int = 0
}

@objc public class NKEditorDetailsEditors: NSObject {

    @objc public var mimetypes: [String] = []
    @objc public var name = ""
    @objc public var optionalMimetypes: [String] = []
    @objc public var secure: Int = 0
}

@objc public class NKEditorTemplates: NSObject {

    @objc public var delete = ""
    @objc public var ext = ""
    @objc public var identifier = ""
    @objc public var name = ""
    @objc public var preview = ""
    @objc public var type = ""
}

@objc public class NKExternalSite: NSObject {

    @objc public var icon = ""
    @objc public var idExternalSite: Int = 0
    @objc public var lang = ""
    @objc public var name = ""
    @objc public var order: Int = 0
    @objc public var type = ""
    @objc public var url = ""
}

@objc public class NKFile: NSObject {

    @objc public var account = ""
    @objc public var classFile = ""
    @objc public var commentsUnread: Bool = false
    @objc public var contentType = ""
    @objc public var checksums = ""
    @objc public var creationDate: NSDate?
    @objc public var dataFingerprint = ""
    @objc public var date = NSDate()
    @objc public var directory: Bool = false
    @objc public var downloadURL = ""
    @objc public var e2eEncrypted: Bool = false
    @objc public var etag = ""
    @objc public var favorite: Bool = false
    @objc public var fileId = ""
    @objc public var fileName = ""
    @objc public var hasPreview: Bool = false
    @objc public var iconName = ""
    @objc public var mountType = ""
    @objc public var name = ""
    @objc public var note = ""
    @objc public var ocId = ""
    @objc public var ownerId = ""
    @objc public var ownerDisplayName = ""
    @objc public var lock = false
    @objc public var lockOwner = ""
    @objc public var lockOwnerEditor = ""
    @objc public var lockOwnerType = 0
    @objc public var lockOwnerDisplayName = ""
    @objc public var lockTime: Date?
    @objc public var lockTimeOut: Date?
    @objc public var path = ""
    @objc public var permissions = ""
    @objc public var quotaUsedBytes: Int64 = 0
    @objc public var quotaAvailableBytes: Int64 = 0
    @objc public var resourceType = ""
    @objc public var richWorkspace: String?
    @objc public var sharePermissionsCollaborationServices: Int = 0
    @objc public var sharePermissionsCloudMesh: [String] = []
    @objc public var shareType: [Int] = []
    @objc public var size: Int64 = 0
    @objc public var serverUrl = ""
    @objc public var tags: [String] = []
    @objc public var trashbinFileName = ""
    @objc public var trashbinOriginalLocation = ""
    @objc public var trashbinDeletionTime = NSDate()
    @objc public var uploadDate: NSDate?
    @objc public var urlBase = ""
    @objc public var user = ""
    @objc public var userId = ""
}

@objcMembers public class NKFileProperty: NSObject {

    public var classFile: String = ""
    public var iconName: String = ""
    public var name: String = ""
    public var ext: String = ""
}

@objc public class NKNotifications: NSObject {

    @objc public var actions: Data?
    @objc public var app = ""
    @objc public var date = NSDate()
    @objc public var icon: String?
    @objc public var idNotification: Int = 0
    @objc public var link = ""
    @objc public var message = ""
    @objc public var messageRich = ""
    @objc public var messageRichParameters: Data?
    @objc public var objectId = ""
    @objc public var objectType = ""
    @objc public var subject = ""
    @objc public var subjectRich = ""
    @objc public var subjectRichParameters: Data?
    @objc public var user = ""
}

@objc public class NKRichdocumentsTemplate: NSObject {

    @objc public var delete = ""
    @objc public var ext = ""
    @objc public var name = ""
    @objc public var preview = ""
    @objc public var templateId: Int = 0
    @objc public var type = ""
}

@objc public class NKSharee: NSObject {

    @objc public var circleInfo = ""
    @objc public var circleOwner = ""
    @objc public var label = ""
    @objc public var name = ""
    @objc public var shareType: Int = 0
    @objc public var shareWith = ""
    @objc public var uuid = ""
    @objc public var userClearAt: NSDate?
    @objc public var userIcon = ""
    @objc public var userMessage = ""
    @objc public var userStatus = ""
}

@objc public class NKTrash: NSObject {

    @objc public var contentType = ""
    @objc public var date = NSDate()
    @objc public var directory: Bool = false
    @objc public var fileId = ""
    @objc public var fileName = ""
    @objc public var filePath = ""
    @objc public var hasPreview: Bool = false
    @objc public var iconName = ""
    @objc public var size: Int64 = 0
    @objc public var classFile = ""
    @objc public var trashbinFileName = ""
    @objc public var trashbinOriginalLocation = ""
    @objc public var trashbinDeletionTime = NSDate()
}

@objc public class NKUserProfile: NSObject {

    @objc public var address = ""
    @objc public var backend = ""
    @objc public var backendCapabilitiesSetDisplayName: Bool = false
    @objc public var backendCapabilitiesSetPassword: Bool = false
    @objc public var displayName = ""
    @objc public var email = ""
    @objc public var enabled: Bool = false
    @objc public var groups: [String] = []
    @objc public var language = ""
    @objc public var lastLogin: Int64 = 0
    @objc public var locale = ""
    @objc public var organisation = ""
    @objc public var phone = ""
    @objc public var quota: Int64 = 0
    @objc public var quotaFree: Int64 = 0
    @objc public var quotaRelative: Double = 0
    @objc public var quotaTotal: Int64 = 0
    @objc public var quotaUsed: Int64 = 0
    @objc public var storageLocation = ""
    @objc public var subadmin: [String] = []
    @objc public var twitter = ""
    @objc public var userId = ""
    @objc public var website = ""
}

@objc public class NKUserStatus: NSObject {

    @objc public var clearAt: NSDate?
    @objc public var clearAtTime: String?
    @objc public var clearAtType: String?
    @objc public var icon: String?
    @objc public var id: String?
    @objc public var message: String?
    @objc public var predefined: Bool = false
    @objc public var status: String?
    @objc public var userId: String?
}

// MARK: - Data File

class NKDataFileXML: NSObject {
    let nkCommonInstance: NKCommon

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

    let propStandard =
    """
    <d:getlastmodified />
    <d:getetag />
    <d:getcontenttype />
    <d:resourcetype />
    <d:quota-available-bytes />
    <d:quota-used-bytes />

    <permissions xmlns=\"http://owncloud.org/ns\"/>
    <id xmlns=\"http://owncloud.org/ns\"/>
    <fileid xmlns=\"http://owncloud.org/ns\"/>
    <size xmlns=\"http://owncloud.org/ns\"/>
    <favorite xmlns=\"http://owncloud.org/ns\"/>
    <share-types xmlns=\"http://owncloud.org/ns\"/>
    <owner-id xmlns=\"http://owncloud.org/ns\"/>
    <owner-display-name xmlns=\"http://owncloud.org/ns\"/>
    <comments-unread xmlns=\"http://owncloud.org/ns\"/>
    <checksums xmlns=\"http://owncloud.org/ns\"/>
    <downloadURL xmlns=\"http://owncloud.org/ns\"/>
    <data-fingerprint xmlns=\"http://owncloud.org/ns\"/>

    <creation_time xmlns=\"http://nextcloud.org/ns\"/>
    <upload_time xmlns=\"http://nextcloud.org/ns\"/>
    <is-encrypted xmlns=\"http://nextcloud.org/ns\"/>
    <has-preview xmlns=\"http://nextcloud.org/ns\"/>
    <mount-type xmlns=\"http://nextcloud.org/ns\"/>
    <rich-workspace xmlns=\"http://nextcloud.org/ns\"/>
    <note xmlns=\"http://nextcloud.org/ns\"/>
    <lock xmlns=\"http://nextcloud.org/ns\"/>
    <lock-owner xmlns=\"http://nextcloud.org/ns\"/>
    <lock-owner-editor xmlns=\"http://nextcloud.org/ns\"/>
    <lock-owner-displayname xmlns=\"http://nextcloud.org/ns\"/>
    <lock-owner-type xmlns=\"http://nextcloud.org/ns\"/>
    <lock-time xmlns=\"http://nextcloud.org/ns\"/>
    <lock-timeout xmlns=\"http://nextcloud.org/ns\"/>
    <system-tags xmlns=\"http://nextcloud.org/ns\"/>

    <share-permissions xmlns=\"http://open-collaboration-services.org/ns\"/>
    <share-permissions xmlns=\"http://open-cloud-mesh.org/ns\"/>
    """

    lazy var requestBodyFile: String = {
        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop>
        """ + propStandard + """
            </d:prop>
        </d:propfind>
        """
    }()

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

    lazy var requestBodyFileListingFavorites: String = {
        return """
        <?xml version=\"1.0\"?>
        <oc:filter-files xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop>
        """ + propStandard + """
            </d:prop>
            <oc:filter-rules>
                <oc:favorite>1</oc:favorite>
            </oc:filter-rules>
        </oc:filter-files>
        """
    }()

    lazy var requestBodySearchFileName: String = {
        return """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
            <d:select>
                <d:prop>
        """ + propStandard + """
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
    }()

    lazy var requestBodySearchFileId: String = {
        return """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
            <d:select>
                <d:prop>
        """ + propStandard + """
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
    }()

    lazy var requestBodySearchLessThan: String = {
        return """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
        <d:select>
            <d:prop>
        """ + propStandard + """
            </d:prop>
        </d:select>
        <d:from>
            <d:scope>
                <d:href>%@</d:href>
                <d:depth>infinity</d:depth>
            </d:scope>
        </d:from>
        <d:where>
            <d:lt>
                <d:prop><d:getlastmodified/></d:prop>
                <d:literal>%@</d:literal>
            </d:lt>
        </d:where>
            <d:limit>
                <d:nresults>%@</d:nresults>
            </d:limit>
        </d:basicsearch>
        </d:searchrequest>
        """
    }()

    lazy var requestBodySearchMedia: String = {
        return """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
        <d:select>
        <d:prop>
        """ + propStandard + """
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
        </d:basicsearch>
        </d:searchrequest>
        """
    }()

    lazy var requestBodySearchMediaWithLimit: String = {
        return """
        <?xml version=\"1.0\"?>
        <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:basicsearch>
        <d:select>
            <d:prop>
        """ + propStandard + """
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
    }()

    let requestBodyTrash =
    """
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:prop>
            <d:displayname />
            <d:getcontenttype />
            <d:resourcetype />
            <d:getcontentlength />
            <d:getlastmodified />
            <d:getetag />
            <d:quota-used-bytes />
            <d:quota-available-bytes />
            <permissions xmlns=\"http://owncloud.org/ns\"/>

            <id xmlns=\"http://owncloud.org/ns\"/>
            <fileid xmlns=\"http://owncloud.org/ns\"/>
            <size xmlns=\"http://owncloud.org/ns\"/>
            <favorite xmlns=\"http://owncloud.org/ns\"/>
            <is-encrypted xmlns=\"http://nextcloud.org/ns\"/>
            <mount-type xmlns=\"http://nextcloud.org/ns\"/>
            <owner-id xmlns=\"http://owncloud.org/ns\"/>
            <owner-display-name xmlns=\"http://owncloud.org/ns\"/>
            <comments-unread xmlns=\"http://owncloud.org/ns\"/>
            <has-preview xmlns=\"http://nextcloud.org/ns\"/>

            <trashbin-filename xmlns=\"http://nextcloud.org/ns\"/>
            <trashbin-original-location xmlns=\"http://nextcloud.org/ns\"/>
            <trashbin-deletion-time xmlns=\"http://nextcloud.org/ns\"/>
        </d:prop>
    </d:propfind>
    """

    init(nkCommonInstance: NKCommon) {
        self.nkCommonInstance = nkCommonInstance
        super.init()
    }

    func convertDataAppPassword(data: Data) -> String? {

        let xml = XML.parse(data)
        return xml["ocs", "data", "apppassword"].text
    }

    func convertDataFile(xmlData: Data, dav: String, urlBase: String, user: String, userId: String, showHiddenFiles: Bool, includeHiddenFiles: [String]) -> [NKFile] {

        var files: [NKFile] = []
        let rootFiles = "/" + dav + "/files/"
        guard let baseUrl = self.nkCommonInstance.getHostName(urlString: urlBase) else {
            return files
        }

        let xml = XML.parse(xmlData)
        let elements = xml["d:multistatus", "d:response"]
        for element in elements {
            let file = NKFile()
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
                file.account = self.nkCommonInstance.account

                // path
                file.path = (fileNamePath as NSString).deletingLastPathComponent + "/"
                file.path = file.path.removingPercentEncoding ?? ""

                // fileName
                file.fileName = (fileNamePath as NSString).lastPathComponent
                file.fileName = file.fileName.removingPercentEncoding ?? ""

                // ServerUrl
                if href == rootFiles + user + "/" {
                    file.fileName = "."
                    file.serverUrl = ".."
                } else {
                    file.serverUrl = baseUrl + file.path.dropLast()
                }
            }

            let propstat = element["d:propstat"][0]

            if let getlastmodified = propstat["d:prop", "d:getlastmodified"].text, let date = self.nkCommonInstance.convertDate(getlastmodified, format: "EEE, dd MMM y HH:mm:ss zzz") {
                file.date = date
            }

            if let creationtime = propstat["d:prop", "nc:creation_time"].double, creationtime > 0 {
                file.creationDate = NSDate(timeIntervalSince1970: creationtime)
            }

            if let uploadtime = propstat["d:prop", "nc:upload_time"].double, uploadtime > 0 {
                file.uploadDate = NSDate(timeIntervalSince1970: uploadtime)
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
                file.lock = NSNumber(integerLiteral: lock).boolValue

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
            }

            let tagsElements = propstat["d:prop", "nc:system-tags"]
            for element in tagsElements["nc:system-tag"] {
                guard let tag = element.text else { continue }
                file.tags.append(tag)
            }

            let results = self.nkCommonInstance.getInternalType(fileName: file.fileName, mimeType: file.contentType, directory: file.directory)

            file.contentType = results.mimeType
            file.iconName = results.iconName
            file.name = "files"
            file.classFile = results.classFile
            file.urlBase = urlBase
            file.user = user
            file.userId = userId
            

            files.append(file)
        }

        return files
    }

    func convertDataTrash(xmlData: Data, urlBase: String, showHiddenFiles: Bool) -> [NKTrash] {

        var files: [NKTrash] = []
        var first: Bool = true
        guard let baseUrl = self.nkCommonInstance.getHostName(urlString: urlBase) else {
            return files
        }

        let xml = XML.parse(xmlData)
        let elements = xml["d:multistatus", "d:response"]
        for element in elements {
            if first {
                first = false
                continue
            }
            let file = NKTrash()
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

            if let getlastmodified = propstat["d:prop", "d:getlastmodified"].text, let date = self.nkCommonInstance.convertDate(getlastmodified, format: "EEE, dd MMM y HH:mm:ss zzz") {
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
                file.trashbinDeletionTime = Date(timeIntervalSince1970: trashbinDeletionTimeDouble) as NSDate
            }

            let results = self.nkCommonInstance.getInternalType(fileName: file.trashbinFileName, mimeType: file.contentType, directory: file.directory)

            file.contentType = results.mimeType
            file.classFile = results.classFile
            file.iconName = results.iconName

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

            if let creationDateTime = element["d:propstat", "d:prop", "oc:creationDateTime"].text, let date = self.nkCommonInstance.convertDate(creationDateTime, format: "EEE, dd MMM y HH:mm:ss zzz") {
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
