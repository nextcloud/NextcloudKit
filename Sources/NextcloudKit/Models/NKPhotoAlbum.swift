// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NKPhotoAlbum {
    let account: String
    let href: String
    let lastPhotoId: String?
    let itemCount: Int?
    let location: String?
    let dateRange: String?
    let collaborators: String?
}
