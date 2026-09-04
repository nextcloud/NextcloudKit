// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

enum UnifiedShareListState {
    case loading
    case loaded([NKUnifiedShare])
    case error(Error)
}

@MainActor
@Observable
public class UnifiedShareListModel {
    var state: UnifiedShareListState = .loading
    var permissionPresets: [NKUnifiedSharePermissionPreset] = []
    var recipientsUpdatingPermissions: Set<UnifiedShareRecipientIdentity> = []
    /// Handler for failures that shouldn't replace visible content (the app shows a banner).
    let onError: ((NKError) -> Void)?
    let account: String
    let sourceId: String?

    init(account: String, sourceId: String?, onError: ((NKError) -> Void)? = nil) {
        self.account = account
        self.sourceId = sourceId
        self.onError = onError
    }

#if DEBUG
    /// Preview-only initializer that starts with preloaded shares and capabilities.
    init(account: String,
         sourceId: String? = nil,
         state: UnifiedShareListState,
         permissionPresets: [NKUnifiedSharePermissionPreset] = []) {
        self.account = account
        self.sourceId = sourceId
        self.onError = nil
        self.state = state
        self.permissionPresets = permissionPresets
    }
#endif

    func load() {
        Task {
            if permissionPresets.isEmpty {
                let capabilities = await NextcloudKit.shared.getUnifiedSharingCapabilities(account: account)
                permissionPresets = capabilities.capabilities?.permissionPresets ?? []
            }

            await refresh()
        }
    }

    func refresh() async {
        let result = await NextcloudKit.shared.listUnifiedShares(
            filterSourceTypeClass: UnifiedShareEditModel.nodeSourceClass,
            filterSourceTypeValue: sourceId,
            filterState: .active,
            account: account
        )

        guard let shares = result.shares else {
            // A visible list is kept; only the first load takes the full-page error.
            if case .loaded = state {
                onError?(result.error)
            } else {
                state = .error(result.error)
            }

            return
        }

        state = .loaded(shares)
    }

    func applicablePresets(_ recipient: NKUnifiedShareRecipient, in share: NKUnifiedShare) -> [NKUnifiedSharePermissionPreset] {
        let permissions = recipient.permissions.isEmpty ? share.permissions : recipient.permissions
        let applicable = Set(permissions.flatMap { $0.presets })
        return permissionPresets.filter { applicable.contains($0.class) }
    }

    func setPermissionPreset(share: NKUnifiedShare,
                             recipient: NKUnifiedShareRecipient,
                             presetClass: String) {
        let recipientID = permissionUpdateIdentity(share: share, recipient: recipient)
        guard recipientsUpdatingPermissions.insert(recipientID).inserted else { return }

        Task {
            defer { recipientsUpdatingPermissions.remove(recipientID) }

            var currentShare = share
            let permissions = recipient.permissions.isEmpty ? share.permissions : recipient.permissions

            for permission in permissions {
                let enabled = permission.presets.contains(presetClass)
                guard permission.enabled != enabled else {
                    continue
                }

                let result = await NextcloudKit.shared.setUnifiedShareRecipientPermission(
                    id: currentShare.id,
                    recipientClass: recipient.class,
                    recipientValue: recipient.value,
                    recipientInstance: recipient.instance,
                    permissionClass: permission.class,
                    enabled: enabled,
                    account: account
                )
                guard let updated = result.share else {
                    replace(currentShare)
                    onError?(result.error)
                    return
                }

                currentShare = updated
            }

            replace(currentShare)
        }
    }

    func isUpdatingPermissions(for recipient: NKUnifiedShareRecipient, in share: NKUnifiedShare) -> Bool {
        recipientsUpdatingPermissions.contains(permissionUpdateIdentity(share: share, recipient: recipient))
    }

    private func permissionUpdateIdentity(share: NKUnifiedShare,
                                          recipient: NKUnifiedShareRecipient) -> UnifiedShareRecipientIdentity {
        UnifiedShareRecipientIdentity(shareID: share.id, recipient: recipient)
    }

    private func replace(_ updated: NKUnifiedShare) {
        if case .loaded(let shares) = state {
            state = .loaded(shares.map { $0.id == updated.id ? updated : $0 })
        }
    }
}
