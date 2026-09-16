// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NKPhotoAlbum {
    public let account: String
    public let href: String
    public let lastPhotoId: String?
    public let itemCount: Int?
    public let location: String?
    public let dateRange: String?
    public let collaborators: String?
}
