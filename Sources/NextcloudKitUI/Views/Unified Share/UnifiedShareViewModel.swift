// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

enum UnifiedShareViewState {
    case loading
    case shareUpdated(share: NKUnifiedShare)
    case recipientsUpdated(recipient: [NKUnifiedShareRecipient])
    case error(Error)
}

@MainActor
@Observable
public class UnifiedShareViewModel {
    var state: UnifiedShareViewState = .loading
    let account: String

    init(account: String) {
        self.account = account
    }

#if DEBUG
    /// Preview-only initializer that starts in a given state.
    init(account: String, state: UnifiedShareViewState) {
        self.account = account
        self.state = state
    }
#endif

    func createShare() {
        Task {
            let result = await NextcloudKit.shared.createUnifiedShare(account: account)
            guard let share = result.share else {
                state = .error(result.error)
                return
            }

            state = .shareUpdated(share: share)
        }
    }

    func searchRecipients(query: String) {
        Task {
            let result = await NextcloudKit.shared.searchUnifiedShareRecipients(query: query, account: account)
            guard let share = result.recipients else {
                state = .error(result.error)
                return
            }

            state = .recipientsUpdated(recipient: share)
        }
    }
}

