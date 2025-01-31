// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

#if swift(<6.0)
public class NKFileProperty: NSObject {
    public var classFile: String = ""
    public var iconName: String = ""
    public var name: String = ""
    public var ext: String = ""
}
#else
public struct NKFileProperty: Sendable {
    public var classFile: String = ""
    public var iconName: String = ""
    public var name: String = ""
    public var ext: String = ""
}
#endif
