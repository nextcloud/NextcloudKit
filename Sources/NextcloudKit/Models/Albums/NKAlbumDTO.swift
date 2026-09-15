// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NKAlbumDTO {
    let href: String
    let lastPhotoId: String?
    let itemCount: Int?
    let location: String?
    let dateRange: String?
    let collaborators: String?
}
