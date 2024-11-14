// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKSharee: NSObject {
    public var circleInfo = ""
    public var circleOwner = ""
    public var label = ""
    public var name = ""
    public var shareType: Int = 0
    public var shareWith = ""
    public var uuid = ""
    public var userClearAt: Date?
    public var userIcon = ""
    public var userMessage = ""
    public var userStatus = ""
}
