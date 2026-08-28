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
    /// Handler for failures that shouldn't replace visible content (the app shows a banner).
    let onError: ((NKError) -> Void)?
    let account: String
    let sourceId: String?

    init(account: String, sourceId: String?, onError: ((NKError) -> Void)? = nil) {
        self.account = account
        self.sourceId = sourceId
        self.onError = onError
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

    func applicablePresets(_ share: NKUnifiedShare) -> [NKUnifiedSharePermissionPreset] {
        let applicable = Set(share.permissions.flatMap { $0.presets })
        return permissionPresets.filter { applicable.contains($0.class) }
    }

    func setPermissionPreset(share: NKUnifiedShare, presetClass: String) {
        Task {
            let result = await NextcloudKit.shared.setUnifiedSharePermissionPreset(id: share.id, permissionPresetClass: presetClass, account: account)
            guard let updated = result.share else {
                onError?(result.error)
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
        Task {
            let result = await NextcloudKit.shared.deleteUnifiedShare(id: share.id, account: account)

            guard result.error == .success else {
                onError?(result.error)
                return
            }

            if case .loaded(let shares) = state {
                state = .loaded(shares.filter { $0.id != share.id })
            }
        }
    }
}
