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
import MobileCoreServices
import SwiftyXMLParser
import SwiftyJSON

// MARK: - Hovercard

@objc public class NKHovercard: NSObject {
    internal init?(jsonData: JSON) {
        guard let userId = jsonData["userId"].string,
              let displayName = jsonData["displayName"].string,
              let actions = jsonData["actions"].array?.compactMap(Action.init)
        else {
            return nil
        }
        self.userId = userId
        self.displayName = displayName
        self.actions = actions
    }

    @objc public class Action: NSObject {
        internal init?(jsonData: JSON) {
            guard let title = jsonData["title"].string,
                  let icon = jsonData["icon"].string,
                  let hyperlink = jsonData["hyperlink"].string,
                  let appId = jsonData["appId"].string
            else {
                return nil
            }
            self.title = title
            self.icon = icon
            self.hyperlink = hyperlink
            self.appId = appId
        }

        @objc public let title: String
        @objc public let icon: String
        @objc public let hyperlink: String
        @objc public var hyperlinkUrl: URL? { URL(string: hyperlink) }
        @objc public let appId: String
    }

    @objc public let userId, displayName: String
    @objc public let actions: [Action]
}

// MARK: - Unified Search

@objc public class NKSearchResult: NSObject {
    
    @objc public let id: String
    @objc public let name: String
    @objc public let isPaginated: Bool
    @objc public let entries: [NKSearchEntry]
    public let cursor: Int?

    init?(json: JSON, id: String) {
        guard let isPaginated = json["isPaginated"].bool,
              let name = json["name"].string,
              let entries = NKSearchEntry.factory(jsonArray: json["entries"])
        else { return nil }
        self.id = id
        self.cursor = json["cursor"].int
        self.name = name
        self.isPaginated = isPaginated
        self.entries = entries
    }
}

@objc public class NKSearchEntry: NSObject {
    
    @objc public let thumbnailURL: String
    @objc public let title, subline: String
    @objc public let resourceURL: String
    @objc public let icon: String
    @objc public let rounded: Bool
    @objc public let attributes: [String: Any]?

    public var fileId: Int? {
        guard let fileAttribute = attributes?["fileId"] as? String else { return nil }
        return Int(fileAttribute)
    }

    @objc public var filePath: String? {
        attributes?["path"] as? String
    }

    init?(json: JSON) {
        guard let thumbnailURL = json["thumbnailUrl"].string,
              let title = json["title"].string,
              let subline = json["subline"].string,
              let resourceURL = json["resourceUrl"].string,
              let icon = json["icon"].string,
              let rounded = json["rounded"].bool
        else { return nil }

        self.thumbnailURL = thumbnailURL
        self.title = title
        self.subline = subline
        self.resourceURL = resourceURL
        self.icon = icon
        self.rounded = rounded
        self.attributes = json["attributes"].dictionaryObject
    }

    static func factory(jsonArray: JSON) -> [NKSearchEntry]? {
        guard let allProvider = jsonArray.array else { return nil }
        return allProvider.compactMap(NKSearchEntry.init)
    }
}

@objc public class NKSearchProvider: NSObject {
    
    init?(json: JSON) {
        guard let id = json["id"].string,
              let name = json["name"].string,
              let order = json["order"].int
        else { return nil }
        self.id = id
        self.name = name
        self.order = order
    }

    @objc public let id, name: String
    @objc public let order: Int

    static func factory(jsonArray: JSON) -> [NKSearchProvider]? {
        guard let allProvider = jsonArray.array else { return nil }
        return allProvider.compactMap(NKSearchProvider.init)
    }
}

// MARK: - Dashboard

@objc public class NCCDashboardItemsResult: NSObject {
    
    @objc public var application: String?
    @objc public var dashboardEntries: [NCCDashboardItem]?

    init?(application: String, data: JSON) {
        self.application = application
        self.dashboardEntries = NCCDashboardItem.factory(data: data)
    }

    static func factory(data: JSON) -> [NCCDashboardItemsResult] {
        var dashboardResults = [NCCDashboardItemsResult]()
        for (application, data):(String, JSON) in data {
            if let result = NCCDashboardItemsResult.init(application: application, data: data) {
                dashboardResults.append(result)
            }
        }
        return dashboardResults
    }
}

@objc public class NCCDashboardItem: NSObject {
    
    @objc public let title: String?
    @objc public let subtitle: String?
    @objc public let link: String?
    @objc public let iconUrl: String?
    @objc public let sinceId: Int

    init?(json: JSON) {
        self.title = json["title"].string
        self.subtitle = json["subtitle"].string
        self.link = json["link"].string
        self.iconUrl = json["iconUrl"].string
        self.sinceId = json["sinceId"].int ?? 0
    }

    static func factory(data: JSON) -> [NCCDashboardItem]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NCCDashboardItem.init)
    }
}

// MARK: - ccccccccccc

@objc public class NCCDashboardWidgets: NSObject {
    
    @objc public var application: String?
    @objc public var items: [NCCDashboardWidgetItem]?

    init?(application: String, data: JSON) {
        self.application = application
        self.items = NCCDashboardWidgetItem.factory(data: data)
    }

    static func factory(data: JSON) -> [NCCDashboardWidgetItem] {
        var widgets = [NCCDashboardWidgetItem]()
        for (_, data):(String, JSON) in data {
            if let result = NCCDashboardWidgetItem(json: data) {
                widgets.append(result)
            }
        }
        return widgets
    }
    
}

@objc public class NCCDashboardWidgetItem: NSObject {
    
    @objc public let id, title: String
    @objc public let order: Int
    @objc public let iconClass, iconUrl, widgetUrl: String?
    @objc public var buttons: [NCCDashboardWidgetItemButton]?

    init?(json: JSON) {
        guard let id = json["id"].string,
              let title = json["title"].string
        else { return nil }
        self.id = id
        self.title = title
        self.order = json["order"].int ?? 0
        self.iconClass = json["icon_class"].string
        self.iconUrl = json["icon_url"].string
        self.widgetUrl = json["icon_url"].string
        if let buttonsData = json["buttons"].array {
            print("")
            //self.buttons = NCCDashboardWidgetItemButton.factory(data: buttonsData)
        }
    }

    static func factory(data: JSON) -> [NCCDashboardWidgetItem]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NCCDashboardWidgetItem.init)
    }
}

@objc public class NCCDashboardWidgetItemButton: NSObject {
    
    @objc public let type, text, link: String
    
    init?(json: JSON) {
        guard let type = json["type"].string,
              let text = json["text"].string,
              let link = json["link"].string
        else { return nil }
        self.type = type
        self.text = text
        self.link = link
    }

    static func factory(data: JSON) -> [NCCDashboardWidgetItemButton]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NCCDashboardWidgetItemButton.init)
    }
}

// MARK: -


@objc public class NKActivity: NSObject {
    
    @objc public var app = ""
    @objc public var date = NSDate()
    @objc public var idActivity: Int = 0
    @objc public var icon = ""
    @objc public var link = ""
    @objc public var message = ""
    @objc public var message_rich: Data?
    @objc public var object_id: Int = 0
    @objc public var object_name = ""
    @objc public var object_type = ""
    @objc public var previews: Data?
    @objc public var subject = ""
    @objc public var subject_rich: Data?
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
    @objc public var type = ""
    @objc public var url = ""
}

@objc public class NKFile: NSObject {
    
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
    @objc public var ext = ""
    @objc public var favorite: Bool = false
    @objc public var fileId = ""
    @objc public var fileName = ""
    @objc public var fileNameWithoutExt = ""
    @objc public var hasPreview: Bool = false
    @objc public var iconName = ""
    @objc public var livePhoto: Bool = false
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
    @objc public var trashbinFileName = ""
    @objc public var trashbinOriginalLocation = ""
    @objc public var trashbinDeletionTime = NSDate()
    @objc public var uploadDate: NSDate?
    @objc public var urlBase = ""
    @objc public var user = ""
    @objc public var userId = ""
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

@objc public class NKShare: NSObject {
    
    @objc public var canEdit: Bool = false
    @objc public var canDelete: Bool = false
    @objc public var date: NSDate?
    @objc public var displaynameFileOwner = ""
    @objc public var displaynameOwner = ""
    @objc public var expirationDate: NSDate?
    @objc public var fileParent: Int = 0
    @objc public var fileSource: Int = 0
    @objc public var fileTarget = ""
    @objc public var hideDownload: Bool = false
    @objc public var idShare: Int = 0
    @objc public var itemSource: Int = 0
    @objc public var itemType = ""
    @objc public var label = ""
    @objc public var mailSend: Bool = false
    @objc public var mimeType = ""
    @objc public var note = ""
    @objc public var parent: String = ""
    @objc public var password: String = ""
    @objc public var path = ""
    @objc public var permissions: Int = 0
    @objc public var sendPasswordByTalk: Bool = false
    @objc public var shareType: Int = 0
    @objc public var shareWith = ""
    @objc public var shareWithDisplayname = ""
    @objc public var storage: Int = 0
    @objc public var storageId = ""
    @objc public var token = ""
    @objc public var uidFileOwner = ""
    @objc public var uidOwner = ""
    @objc public var url = ""
    @objc public var userClearAt: NSDate?
    @objc public var userIcon = ""
    @objc public var userMessage = ""
    @objc public var userStatus = ""
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

//MARK: - Data File

class NKDataFileXML: NSObject {

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
    
    let requestBodyFile =
    """
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:prop>
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
            <lock-owner-type xmlns="http://nextcloud.org/ns"/>
            <lock-time xmlns=\"http://nextcloud.org/ns\"/>
            <lock-timeout xmlns=\"http://nextcloud.org/ns\"/>


            <share-permissions xmlns=\"http://open-collaboration-services.org/ns\"/>
            <share-permissions xmlns=\"http://open-cloud-mesh.org/ns\"/>
        </d:prop>
    </d:propfind>
    """
    
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
    
    let requestBodyFileListingFavorites =
    """
    <?xml version=\"1.0\"?>
    <oc:filter-files xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
        <d:prop>
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
            <lock-time xmlns=\"http://nextcloud.org/ns\"/>
            <lock-timeout xmlns=\"http://nextcloud.org/ns\"/>
            <lock-owner-editor xmlns="http://nextcloud.org/ns"/>
            <lock-owner-type xmlns="http://nextcloud.org/ns"/>
            <lock-token xmlns="http://nextcloud.org/ns"/>

            <share-permissions xmlns=\"http://open-collaboration-services.org/ns\"/>
            <share-permissions xmlns=\"http://open-cloud-mesh.org/ns\"/>
        </d:prop>
        <oc:filter-rules>
            <oc:favorite>1</oc:favorite>
        </oc:filter-rules>
    </oc:filter-files>
    """
    
    let requestBodySearchFileName =
    """
    <?xml version=\"1.0\"?>
    <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
    <d:basicsearch>
        <d:select>
            <d:prop>
                <d:displayname/>
                <d:getcontenttype/>
                <d:resourcetype/>
                <d:getcontentlength/>
                <d:getlastmodified/>
                <d:getetag/>
                <d:quota-used-bytes/>
                <d:quota-available-bytes/>
                <permissions xmlns=\"http://owncloud.org/ns\"/>
                <id xmlns=\"http://owncloud.org/ns\"/>
                <fileid xmlns=\"http://owncloud.org/ns\"/>
                <size xmlns=\"http://owncloud.org/ns\"/>
                <favorite xmlns=\"http://owncloud.org/ns\"/>
                <creation_time xmlns=\"http://nextcloud.org/ns\"/>
                <upload_time xmlns=\"http://nextcloud.org/ns\"/>
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
        </d:select>
    <d:from>
        <d:scope>
            <d:href>%@</d:href>
            <d:depth>%@</d:depth>
        </d:scope>
    </d:from>
    <d:where>
        <d:like>
            <d:prop>
                <d:displayname/>
            </d:prop>
            <d:literal>%@</d:literal>
        </d:like>
    </d:where>
    </d:basicsearch>
    </d:searchrequest>
    """
    
    let requestBodySearchMedia =
    """
    <?xml version=\"1.0\"?>
    <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
      <d:basicsearch>
        <d:select>
          <d:prop>
            <d:displayname/>
            <d:getcontenttype/>
            <d:resourcetype/>
            <d:getcontentlength/>
            <d:getlastmodified/>
            <d:getetag/>
            <d:quota-used-bytes/>
            <d:quota-available-bytes/>
            <permissions xmlns=\"http://owncloud.org/ns\"/>
            <id xmlns=\"http://owncloud.org/ns\"/>
            <fileid xmlns=\"http://owncloud.org/ns\"/>
            <size xmlns=\"http://owncloud.org/ns\"/>
            <favorite xmlns=\"http://owncloud.org/ns\"/>
            <creation_time xmlns=\"http://nextcloud.org/ns\"/>
            <upload_time xmlns=\"http://nextcloud.org/ns\"/>
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
        </d:select>
        <d:from>
          <d:scope>
            <d:href>%@</d:href>
            <d:depth>infinity</d:depth>
          </d:scope>
        </d:from>
        <d:orderby>
          <d:order>
            <d:prop>
              <%@>
            </d:prop>
            <d:descending/>
          </d:order>
          <d:order>
            <d:prop>
              <d:displayname/>
            </d:prop>
            <d:descending/>
          </d:order>
        </d:orderby>
        <d:where>
          <d:and>
            <d:or>
              <d:like>
                <d:prop>
                  <d:getcontenttype/>
                </d:prop>
                <d:literal>image/%%</d:literal>
              </d:like>
              <d:like>
                <d:prop>
                  <d:getcontenttype/>
                </d:prop>
                <d:literal>video/%%</d:literal>
              </d:like>
            </d:or>
            <d:or>
              <d:and>
                <d:lt>
                  <d:prop>
                    <%@>
                  </d:prop>
                  <d:literal>%@</d:literal>
                </d:lt>
                <d:gt>
                  <d:prop>
                    <%@>
                  </d:prop>
                  <d:literal>%@</d:literal>
                </d:gt>
              </d:and>
            </d:or>
          </d:and>
        </d:where>
      </d:basicsearch>
    </d:searchrequest>
    """
    
    let requestBodySearchMediaWithLimit =
    """
    <?xml version=\"1.0\"?>
    <d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
      <d:basicsearch>
        <d:select>
          <d:prop>
            <d:displayname/>
            <d:getcontenttype/>
            <d:resourcetype/>
            <d:getcontentlength/>
            <d:getlastmodified/>
            <d:getetag/>
            <d:quota-used-bytes/>
            <d:quota-available-bytes/>
            <permissions xmlns=\"http://owncloud.org/ns\"/>
            <id xmlns=\"http://owncloud.org/ns\"/>
            <fileid xmlns=\"http://owncloud.org/ns\"/>
            <size xmlns=\"http://owncloud.org/ns\"/>
            <favorite xmlns=\"http://owncloud.org/ns\"/>
            <creation_time xmlns=\"http://nextcloud.org/ns\"/>
            <upload_time xmlns=\"http://nextcloud.org/ns\"/>
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
        </d:select>
        <d:from>
          <d:scope>
            <d:href>%@</d:href>
            <d:depth>infinity</d:depth>
          </d:scope>
        </d:from>
        <d:orderby>
          <d:order>
            <d:prop>
              <%@>
            </d:prop>
            <d:descending/>
          </d:order>
          <d:order>
            <d:prop>
              <d:displayname/>
            </d:prop>
            <d:descending/>
          </d:order>
        </d:orderby>
        <d:where>
          <d:and>
            <d:or>
              <d:like>
                <d:prop>
                  <d:getcontenttype/>
                </d:prop>
                <d:literal>image/%%</d:literal>
              </d:like>
              <d:like>
                <d:prop>
                  <d:getcontenttype/>
                </d:prop>
                <d:literal>video/%%</d:literal>
              </d:like>
            </d:or>
            <d:or>
              <d:and>
                <d:lt>
                  <d:prop>
                    <%@>
                  </d:prop>
                  <d:literal>%@</d:literal>
                </d:lt>
                <d:gt>
                  <d:prop>
                    <%@>
                  </d:prop>
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
    
    func convertDataAppPassword(data: Data) -> String? {
        
        let xml = XML.parse(data)
        return xml["ocs", "data", "apppassword"].text
    }
    
    func convertDataFile(data: Data, user: String, userId: String, showHiddenFiles: Bool) -> [NKFile] {
        
        var files: [NKFile] = []
        var dicMOV: [String:Int] = [:]
        var dicImage: [String:Int] = [:]
        let rootFiles = "/" + NKCommon.shared.dav + "/files/"
        guard let baseUrl = NKCommon.shared.getHostName(urlString: NKCommon.shared.urlBase) else {
            return files
        }
        
        let xml = XML.parse(data)
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
                    let componentsFiltered = componentsPath.filter {
                        $0.hasPrefix(".")
                    }
                    if componentsFiltered.count > 0 { continue }
                }
                
                // path
                file.path = (fileNamePath as NSString).deletingLastPathComponent + "/"
                file.path = file.path.removingPercentEncoding ?? ""
                
                // fileName
                file.fileName = (fileNamePath as NSString).lastPathComponent
                file.fileName = file.fileName.removingPercentEncoding ?? ""
              
                // ServerUrl
                if href == rootFiles + NKCommon.shared.user + "/" {
                    file.fileName = "."
                    file.serverUrl = ".."
                } else {
                    file.serverUrl = baseUrl + file.path.dropLast()
                }
                file.serverUrl = file.serverUrl.removingPercentEncoding ?? ""
            }
            
            let propstat = element["d:propstat"][0]
                        
            if let getlastmodified = propstat["d:prop", "d:getlastmodified"].text {
                if let date = NKCommon.shared.convertDate(getlastmodified, format: "EEE, dd MMM y HH:mm:ss zzz") {
                    file.date = date
                }
            }
            
            if let creationtime = propstat["d:prop", "nc:creation_time"].double {
                if creationtime > 0 {
                    file.creationDate = NSDate(timeIntervalSince1970: creationtime)
                }
            }
            
            if let uploadtime = propstat["d:prop", "nc:upload_time"].double {
                if uploadtime > 0 {
                    file.uploadDate = NSDate(timeIntervalSince1970: uploadtime)
                }
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
            
            let results = NKCommon.shared.getInternalType(fileName: file.fileName, mimeType: file.contentType, directory: file.directory)
            
            file.contentType = results.mimeType
            file.ext = results.ext
            file.fileNameWithoutExt = results.fileNameWithoutExt
            file.iconName = results.iconName
            file.name = "files"
            file.classFile = results.classFile
            file.urlBase = NKCommon.shared.urlBase
            file.user = user
            file.userId = userId
            
            files.append(file)
            
            // Detect Live Photo
            if file.ext == "mov" {
                dicMOV[file.fileNameWithoutExt] = files.count - 1
            } else if file.classFile == NKCommon.typeClassFile.image.rawValue {
                dicImage[file.fileNameWithoutExt] = files.count - 1
            }
        }
        
        // Detect Live Photo
        if dicMOV.count > 0 {
            for index in dicImage.values {
                let fileImage = files[index]
                if dicMOV.keys.contains(fileImage.fileNameWithoutExt) {
                    if let index = dicMOV[fileImage.fileNameWithoutExt] {
                        let fileMOV = files[index]
                        fileImage.livePhoto = true
                        fileMOV.livePhoto = true
                        dicMOV[fileImage.fileNameWithoutExt] = nil
                    }
                }
            }
        }
        
        return files
    }
    
    func convertDataTrash(data: Data, showHiddenFiles: Bool) -> [NKTrash] {
        
        var files: [NKTrash] = []
        var first: Bool = true
        guard let baseUrl = NKCommon.shared.getHostName(urlString: NKCommon.shared.urlBase) else {
            return files
        }
    
        let xml = XML.parse(data)
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
                        
            if let getlastmodified = propstat["d:prop", "d:getlastmodified"].text {
                if let date = NKCommon.shared.convertDate(getlastmodified, format: "EEE, dd MMM y HH:mm:ss zzz") {
                    file.date = date
                }
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
            
            if let trashbinDeletionTime = propstat["d:prop", "nc:trashbin-deletion-time"].text {
                if let trashbinDeletionTimeDouble = Double(trashbinDeletionTime) {
                    file.trashbinDeletionTime = Date.init(timeIntervalSince1970: trashbinDeletionTimeDouble) as NSDate
                }
            }

            let results = NKCommon.shared.getInternalType(fileName: file.trashbinFileName, mimeType: file.contentType, directory: file.directory)
            
            file.contentType = results.mimeType
            file.classFile = results.classFile
            file.iconName = results.iconName

            files.append(file)
        }
        
        return files
    }
    
    func convertDataComments(data: Data) -> [NKComments] {
        
        var items: [NKComments] = []
    
        let xml = XML.parse(data)
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
            
            if let creationDateTime = element["d:propstat", "d:prop", "oc:creationDateTime"].text {
                if let date = NKCommon.shared.convertDate(creationDateTime, format: "EEE, dd MMM y HH:mm:ss zzz") {
                    item.creationDateTime = date
                }
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
            
            if let value = element["d:propstat", "d:status"].text {
                if value.contains("200") {
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    func convertDataShare(data: Data) -> (shares: [NKShare], statusCode: Int, message: String) {
        
        var items: [NKShare] = []
        var statusCode: Int = 0
        var message = ""
        
        let xml = XML.parse(data)
        if let value = xml["ocs", "meta", "statuscode"].int {
            statusCode = value
        }
        if let value = xml["ocs", "meta", "message"].text {
            message = value
        }
        let elements = xml["ocs", "data", "element"]
        for element in elements {
            let item = NKShare()

            if let value = element["can_edit"].int {
                item.canEdit = (value as NSNumber).boolValue
            }
            
            if let value = element["can_delete"].int {
                item.canDelete = (value as NSNumber).boolValue
            }
            
            if let value = element["displayname_file_owner"].text {
                item.displaynameFileOwner = value
            }
            
            if let value = element["displayname_owner"].text {
                item.displaynameOwner = value
            }
            
            if let value = element["expiration"].text {
                if let date = NKCommon.shared.convertDate(value, format: "YYYY-MM-dd HH:mm:ss") {
                     item.expirationDate = date
                }
            }
            
            if let value = element["file_parent"].int {
                item.fileParent = value
            }
            
            if let value = element["file_source"].int {
                item.fileSource = value
            }
            
            if let value = element["file_target"].text {
                item.fileTarget = value
            }
            
            if let value = element["hide_download"].int {
                item.hideDownload = (value as NSNumber).boolValue
            }
                        
            if let value = element["id"].int {
                item.idShare = value
            }
            
            if let value = element["item_source"].int {
                item.itemSource = value
            }
            
            if let value = element["item_type"].text {
                item.itemType = value
            }
            
            if let value = element["label"].text {
                item.label = value
            }
            
            if let value = element["mail_send"].int {
                item.mailSend = (value as NSNumber).boolValue
            }
            
            if let value = element["mimetype"].text {
                item.mimeType = value
            }
            
            if let value = element["note"].text {
                item.note = value
            }
            
            if let value = element["parent"].text {
                item.parent = value
            }
            
            if let value = element["password"].text {
                item.password = value
            }
            
            if let value = element["path"].text {
                item.path = value
            }
            
            if let value = element["permissions"].int {
                item.permissions = value
            }
            
            if let value = element["send_password_by_talk"].int {
                item.sendPasswordByTalk = (value as NSNumber).boolValue
            }
            
            if let value = element["share_type"].int {
                item.shareType = value
            }
            
            if let value = element["share_with"].text {
                item.shareWith = value
            }
                       
            if let value = element["share_with_displayname"].text {
                item.shareWithDisplayname = value
            }
            
            if let value = element["stime"].double {
                if value > 0 {
                    item.date = NSDate(timeIntervalSince1970: value)
                }
            }
            
            if let value = element["storage"].int {
                item.storage = value
            }
            
            if let value = element["storage_id"].text {
                item.storageId = value
            }
            
            if let value = element["token"].text {
                item.token = value
            }
            
            if let value = element["uid_file_owner"].text {
                item.uidFileOwner = value
            }
            
            if let value = element["uid_owner"].text {
                item.uidOwner = value
            }
            
            if let value = element["url"].text {
                item.url = value
            }
            
            if let value = element["status","clearAt"].double {
                if value > 0 {
                     item.userClearAt = NSDate(timeIntervalSince1970: value)
                }
            }
            
            if let value = element["status","icon"].text {
                item.userIcon = value
            }
            
            if let value = element["status","message"].text {
                item.userMessage = value
            }
            
            if let value = element["status","status"].text {
                item.userStatus = value
            }
            
            items.append(item)
        }
        
        return(items, statusCode, message)
    }
}

