// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKExternalSite: NSObject {
    public var icon = ""
    public var idExternalSite: Int = 0
    public var lang = ""
    public var name = ""
    public var order: Int = 0
    public var type = ""
    public var url = ""
}
