//  SPDX-FileCopyrightText: 2025 Nextcloud GmbH and Nextcloud contributors
//  SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Represents a Nextcloud share with its associated properties and permissions.
///
public final class NKShare: NSObject {
    ///
    /// Bitmask values defining share permissions as used in `permissions`.
    ///
    /// As defined in the [OCS Share API documentation](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/OCS/ocs-share-api.html).
    ///
    public struct Permission: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Access the shared item.
        /// Default value for public shares.
        public static let read = Permission(rawValue: 1)

        /// Edit the shared item.
        public static let update = Permission(rawValue: 2)

        /// Create the shared item.
        public static let create = Permission(rawValue: 4)

        /// Delete the shared item.
        public static let delete = Permission(rawValue: 8)

        /// Reshare the shared item.
        public static let share = Permission(rawValue: 16)

        /// Default value except for public shares.
        public static let all: Permission = [.read, .update, .create, .delete, .share]

        ///
        /// Determine the default permission value based on the given type value.
        ///
        /// - Parameters:
        ///     - type: The share type enum value.
        ///
        public static func defaultPermission(for type: NKShare.ShareType) -> Permission {
            if type == .publicLink {
                return .read
            } else {
                return .all
            }
        }
    }

    ///
    /// The kind of the share.
    ///
    public enum ShareType: Int {
        ///
        /// A link which works internally only.
        ///
        case internalLink = -1

        ///
        /// A share which is directly tied to a Nextcloud user.
        ///
        case user = 0

        ///
        /// A share which is directly tied to a Nextcloud group.
        ///
        case group = 1

        ///
        /// A publicly accessible link.
        ///
        case publicLink = 3

        ///
        /// Shared by mail.
        ///
        case email = 4

        ///
        /// A federated share.
        ///
        case federatedCloud = 6

        ///
        /// Shared with a Nextcloud team.
        ///
        case team = 7

        ///
        /// Shared by a guest.
        ///
        case guest = 8

        ///
        /// A federated group share.
        ///
        case federatedGroup = 9

        ///
        /// Shared within a Nextcloud Talk conversation.
        ///
        case talkConversation = 10
    }

    public var account = ""
    public var canEdit: Bool = false
    public var canDelete: Bool = false
    public var date: Date?
    public var displaynameFileOwner = ""
    public var displaynameOwner = ""
    public var expirationDate: NSDate?
    public var fileParent: Int = 0
    public var fileSource: Int = 0
    public var fileTarget = ""
    public var hideDownload: Bool = false
    public var idShare: Int = 0
    public var itemSource: Int = 0
    public var itemType = ""
    public var label = ""
    public var mailSend: Bool = false
    public var mimeType = ""
    public var note = ""
    public var parent = ""
    public var password = ""
    public var path = ""

    ///
    /// See ``Permission`` for possible bitmask values.
    ///
    public var permissions: Int = 0

    public var sendPasswordByTalk: Bool = false
    public var shareType: Int = 0
    public var shareWith = ""
    public var shareWithDisplayname = ""
    public var storage: Int = 0
    public var storageId = ""
    public var token = ""
    public var uidFileOwner = ""
    public var uidOwner = ""
    public var url = ""
    public var userClearAt: Date?
    public var userIcon = ""
    public var userMessage = ""
    public var userStatus = ""
    public var attributes: String?
}
