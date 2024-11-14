// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKEditorDetailsEditors: NSObject {
    public var mimetypes: [String] = []
    public var name = ""
    public var optionalMimetypes: [String] = []
    public var secure: Int = 0
}
