// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Data model for a download limit as returned in the WebDAV response for file properties.
///
/// Each relates to a share of a file and is optionally provided by the [Files Download Limit](https://github.com/nextcloud/files_downloadlimit) app for Nextcloud server.
///
public struct NKDownloadLimit: Sendable {
    ///
    /// The number of downloads which already happened.
    ///
    public let count: Int

    ///
    /// Total number of allowed downloas.
    ///
    public let limit: Int

    ///
    /// The token identifying the related share.
    ///
    public let token: String

    init(count: Int, limit: Int, token: String) {
        self.count = count
        self.limit = limit
        self.token = token
    }
}
