// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKComments: NSObject {
    public var actorDisplayName = ""
    public var actorId = ""
    public var actorType = ""
    public var creationDateTime = Date()
    public var isUnread: Bool = false
    public var message = ""
    public var messageId = ""
    public var objectId = ""
    public var objectType = ""
    public var path = ""
    public var verb = ""
}
