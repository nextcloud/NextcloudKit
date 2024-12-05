// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKTrash: NSObject {
    public var ocId = ""
    public var contentType = ""
    public var date = Date()
    public var directory: Bool = false
    public var fileId = ""
    public var fileName = ""
    public var filePath = ""
    public var hasPreview: Bool = false
    public var iconName = ""
    public var size: Int64 = 0
    public var classFile = ""
    public var trashbinFileName = ""
    public var trashbinOriginalLocation = ""
    public var trashbinDeletionTime = Date()
}
