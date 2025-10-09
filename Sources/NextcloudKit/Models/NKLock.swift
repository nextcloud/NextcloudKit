//  SPDX-FileCopyrightText: 2025 Nextcloud GmbH and Nextcloud contributors
//  SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftyXMLParser

///
/// Description of a file lock.
///
/// This is based on the description of the [`files_lock`](https://github.com/nextcloud/files_lock) server app.
///
public struct NKLock: Equatable, Sendable {
    ///
    /// User id of the owning user.
    ///
    public let owner: String

    ///
    /// App id of an app owned lock to allow clients to suggest joining the collaborative editing session through the web or direct editing.
    ///
    public let ownerEditor: String?

    ///
    /// What kind of lock this is.
    ///
    public let ownerType: NKLockType

    ///
    /// Display name of the lock owner.
    ///
    public let ownerDisplayName: String

    ///
    /// Timestamp of the lock creation time.
    ///
    public let time: Date?

    ///
    /// TTL of the lock in seconds staring from the creation time.
    /// A value of 0 means the timeout is infinite.
    /// Client implementations should properly handle this specific value.
    ///
    public let timeOut: Date?

    ///
    /// Unique lock token (to be preserved on the client side while holding the lock to sent once full webdav locking is implemented).
    ///
    public let token: String?

    ///
    /// Initialize from a SwiftyXML accessor.
    ///
    /// This is intended for creating an instance based on a superset of required properties returned by a `PROPFIND` request to the server about an item.
    ///
    public init?(xml properties: XML.Accessor) {
        guard let rawIsLocked = properties["nc:lock"].int else {
            return nil
        }

        guard rawIsLocked > 0 else {
            return nil
        }

        guard let owner = properties["nc:lock-owner"].text else {
            return nil
        }

        guard let ownerDisplayName = properties["nc:lock-owner-displayname"].text else {
            return nil
        }

        guard let rawOwnerTypeValue = properties["nc:lock-owner-type"].int, let lockOwnerType = NKLockType(rawValue: rawOwnerTypeValue) else {
            return nil
        }

        guard let rawTime = properties["nc:lock-time"].double else {
            return nil
        }

        guard let rawTimeOut = properties["nc:lock-timeout"].double else {
            return nil
        }

        let lockToken = properties["nc:lock-token"].text

        self.owner = owner
        self.ownerEditor = properties["nc:lock-owner-editor"].text
        self.ownerType = lockOwnerType
        self.ownerDisplayName = ownerDisplayName
        self.time = Date(timeIntervalSince1970: rawTime)
        self.timeOut = Date(timeIntervalSince1970: rawTime + rawTimeOut)
        self.token = lockToken
    }

    ///
    /// Initialize from the response body data of an WebDAV request.
    ///
    public init?(data: Data) {
        let properties = XML.parse(data)["d:prop"]
        self.init(xml: properties)
    }

    ///
    /// Initialize from raw values.
    ///
    public init(owner: String, ownerEditor: String, ownerType: NKLockType, ownerDisplayName: String, time: Date?, timeOut: Date?, token: String?) {
        self.owner = owner
        self.ownerEditor = ownerEditor
        self.ownerType = ownerType
        self.ownerDisplayName = ownerDisplayName
        self.time = time
        self.timeOut = timeOut
        self.token = token
    }
}
