// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Lifecycle state of a unified share.
public enum NKUnifiedShareState: String, Codable, Sendable {
    case active
    case draft
    case deleted
}
