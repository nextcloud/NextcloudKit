// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum NKGovernanceLabelType: String, Sendable, Equatable, Hashable {
    case sensitivity = "SENSITIVITY"
    case retention = "RETENTION"
    case hold = "HOLD"
}
