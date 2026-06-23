// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

enum UnifiedShareViewState {
    case loading
    case shareUpdated(share: NKUnifiedShare)
    case error(Error)
}

@MainActor
@Observable
public class UnifiedShareEditModel {
    var state: UnifiedShareViewState = .loading
    /// Recipient autocomplete results — coexist with a loaded share, so kept out of `state`.
    var recipientResults: [NKUnifiedShareRecipient] = []
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
        guard !query.isEmpty else {
            recipientResults = []
            return
        }

        Task {
            let result = await NextcloudKit.shared.searchUnifiedShareRecipients(query: query, account: account)

            recipientResults = result.recipients ?? []
        }
    }

    func deleteShare(share: NKUnifiedShare) {
        Task {
            await NextcloudKit.shared.deleteUnifiedShare(id: share.id, account: account)
        }
    }

    func updateShare(share: NKUnifiedShare, recipient: NKUnifiedShareRecipient) {
        Task {
            let result = await NextcloudKit.shared.addUnifiedShareRecipient(id: share.id, recipientClass: recipient.class, value: recipient.value, account: account)
            guard let share = result.share else {
                state = .error(result.error)
                return
            }

            state = .shareUpdated(share: share)
        }
    }
}

