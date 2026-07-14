// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum NKGovernanceLabelScope: String, Codable, Sendable, Equatable, Hashable {
    case files = "FILES"
    case mails = "MAILS"
}
