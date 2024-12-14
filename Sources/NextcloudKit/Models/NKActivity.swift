// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKActivity: NSObject {
    public var app = ""
    public var date = Date()
    public var idActivity: Int = 0
    public var icon = ""
    public var link = ""
    public var message = ""
    public var messageRich: Data?
    public var objectId: Int = 0
    public var objectName = ""
    public var objectType = ""
    public var previews: Data?
    public var subject = ""
    public var subjectRich: Data?
    public var type = ""
    public var user = ""
}
