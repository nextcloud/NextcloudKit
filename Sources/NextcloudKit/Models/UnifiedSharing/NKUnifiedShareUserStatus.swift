// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The current user's standing on a unified share they received.
public enum NKUnifiedShareUserStatus: String, Codable, Sendable {
    case pending
    case accepted
    case rejected
}
