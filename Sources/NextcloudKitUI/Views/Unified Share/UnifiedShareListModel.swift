// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

extension Notification.Name {
    /// Posted when a share is created/activated elsewhere, so any visible list can refresh.
    static let unifiedShareDidChange = Notification.Name("unifiedShareDidChange")
}

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
    let account: String
    let sourceId: String?

    init(account: String, sourceId: String?) {
        self.account = account
        self.sourceId = sourceId
    }

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
            account: account
        )

        guard let shares = result.shares else {
            state = .error(result.error)
            return
        }

        // Only active shares are shown; drafts are in-progress and deleted ones are gone.
        state = .loaded(shares.filter { $0.state == .active })
    }

    func applicablePresets(_ share: NKUnifiedShare) -> [NKUnifiedSharePermissionPreset] {
        let applicable = Set(share.permissions.flatMap { $0.presets })
        return permissionPresets.filter { applicable.contains($0.class) }
    }

    func setPermissionPreset(share: NKUnifiedShare, presetClass: String) {
        Task {
            let result = await NextcloudKit.shared.setUnifiedSharePermissionPreset(id: share.id, permissionPresetClass: presetClass, account: account)
            guard let updated = result.share else {
                return
            }

            replace(updated)
        }
    }

    private func replace(_ updated: NKUnifiedShare) {
        if case .loaded(let shares) = state {
            state = .loaded(shares.map { $0.id == updated.id ? updated : $0 })
        }
    }

    func delete(share: NKUnifiedShare) {
        if case .loaded(let shares) = state {
            state = .loaded(shares.filter { $0.id != share.id })
        }

        Task {
            await NextcloudKit.shared.deleteUnifiedShare(id: share.id, account: account)
        }
    }
}
