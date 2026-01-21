// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKUserStatus: NSObject, Identifiable {
    public var clearAt: Date?
    public var clearAtTime: String?
    public var clearAtType: String?
    public var icon: String?
    public var id: String?
    public var message: String?
    public var predefined: Bool = false
    public var status: String?
    public var userId: String?
}
