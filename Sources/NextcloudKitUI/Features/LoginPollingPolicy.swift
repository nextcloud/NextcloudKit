// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

///
/// Decides whether a failed login flow poll keeps the flow alive.
///
enum LoginPollingPolicy {
    ///
    /// Network blips while the user is in the browser, e.g. after switching apps for a second factor, should not end the login.
    ///
    static func isTransient(_ error: NKError) -> Bool {
        switch error.kind {
        case .offline, .timeout, .serverUnreachable, .unavailable, .rateLimited, .cancelled:
            true
        default:
            false
        }
    }
}
