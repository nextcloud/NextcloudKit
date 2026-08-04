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
    /// Selectable permission presets advertised by the server's sharing capability.
    var permissionPresets: [NKUnifiedSharePermissionPreset] = []
    let account: String

    init(account: String) {
        self.account = account
    }

#if DEBUG
    /// Preview-only initializer that starts in a given state.
    init(account: String,
         state: UnifiedShareViewState,
         recipientResults: [NKUnifiedShareRecipient] = [],
         permissionPresets: [NKUnifiedSharePermissionPreset] = []) {
        self.account = account
        self.state = state
        self.recipientResults = recipientResults
        self.permissionPresets = permissionPresets
    }
#endif

    func loadCapabilities() {
        Task {
            let result = await NextcloudKit.shared.getUnifiedSharingCapabilities(account: account)
            permissionPresets = result.capabilities?.permissionPresets ?? []
        }
    }

    func setPermissionPreset(share: NKUnifiedShare, presetClass: String) {
        Task {
            let result = await NextcloudKit.shared.setUnifiedSharePermissionPreset(id: share.id, permissionPresetClass: presetClass, account: account)
            guard let share = result.share else {
                state = .error(result.error)
                return
            }

            state = .shareUpdated(share: share)
        }
    }

    func setPermission(share: NKUnifiedShare, permissionClass: String, enabled: Bool) {
        Task {
            let result = await NextcloudKit.shared.setUnifiedSharePermission(id: share.id, permissionClass: permissionClass, enabled: enabled, account: account)
            guard let share = result.share else {
                state = .error(result.error)
                return
            }

            state = .shareUpdated(share: share)
        }
    }

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

    func addRecipient(share: NKUnifiedShare, recipient: NKUnifiedShareRecipient) {
        Task {
            let result = await NextcloudKit.shared.addUnifiedShareRecipient(id: share.id, recipientClass: recipient.class, value: recipient.value, account: account)
            guard let share = result.share else {
                state = .error(result.error)
                return
            }

            state = .shareUpdated(share: share)
        }
    }

    func removeRecipient(share: NKUnifiedShare, recipient: NKUnifiedShareRecipient) {
        Task {
            let result = await NextcloudKit.shared.removeUnifiedShareRecipient(id: share.id, recipientClass: recipient.class, value: recipient.value, instance: recipient.instance, account: account)
            guard let share = result.share else {
                state = .error(result.error)
                return
            }

            state = .shareUpdated(share: share)
        }
    }
}

