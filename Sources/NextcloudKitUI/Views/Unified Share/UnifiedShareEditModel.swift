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
    /// Server class for a file/folder share source.
    static let nodeSourceClass = "OCA\\Files\\Sharing\\Source\\NodeShareSourceType"
    /// Server class for a public-link (token) recipient.
    static let tokenRecipientClass = "OC\\Core\\Sharing\\Recipient\\TokenShareRecipientType"

    private static let searchDebounce: Duration = .milliseconds(300)
    private static let searchLimit = 10

    var state: UnifiedShareViewState = .loading
    /// Recipient autocomplete results — coexist with a loaded share, so kept out of `state`.
    var recipientResults: [NKUnifiedShareRecipient] = []
    /// Selectable permission presets advertised by the server's sharing capability.
    var permissionPresets: [NKUnifiedSharePermissionPreset] = []
    /// Last property-update error text, keyed by property class (shown under the field).
    var propertyErrors: [String: String] = [:]
    /// Transient mutation failure, shown as an alert while the form stays usable.
    var mutationError: NKError?
    /// A copy-link activation is in flight.
    var isPreparingLink = false
    /// Set once the draft has been activated (sent), so the sheet can dismiss.
    var didActivate = false
    /// Property classes with an update in flight; Send stays disabled until empty.
    var pendingProperties: Set<String> = []
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var propertyTasks: [String: Task<Void, Never>] = [:]
    let account: String
    /// Globally-unique id of the file/folder being shared (attached as the share source).
    let sourceId: String?

    init(account: String, sourceId: String? = nil) {
        self.account = account
        self.sourceId = sourceId
    }

    /// Edit an already-existing share (from the list) rather than creating a new draft.
    init(account: String, existingShare: NKUnifiedShare) {
        self.account = account
        self.sourceId = nil
        self.state = .shareUpdated(share: existingShare)
    }

#if DEBUG
    /// Preview-only initializer that starts in a given state.
    init(account: String,
         state: UnifiedShareViewState,
         recipientResults: [NKUnifiedShareRecipient] = [],
         permissionPresets: [NKUnifiedSharePermissionPreset] = []) {
        self.account = account
        self.sourceId = nil
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
                mutationError = result.error
                return
            }

            state = .shareUpdated(share: share)
        }
    }

    func setPermission(share: NKUnifiedShare, permissionClass: String, enabled: Bool) {
        Task {
            let result = await NextcloudKit.shared.setUnifiedSharePermission(id: share.id, permissionClass: permissionClass, enabled: enabled, account: account)
            guard let share = result.share else {
                mutationError = result.error
                return
            }

            state = .shareUpdated(share: share)
        }
    }

    func createShare() {
        Task {
            let result = await NextcloudKit.shared.createUnifiedShare(account: account)
            guard var share = result.share else {
                state = .error(result.error)
                return
            }

            // Point the draft at the actual file/folder being shared.
            if let sourceId, !sourceId.isEmpty {
                let sourceResult = await NextcloudKit.shared.addUnifiedShareSource(id: share.id, sourceClass: Self.nodeSourceClass, value: sourceId, account: account)
                if let updated = sourceResult.share {
                    share = updated
                } else {
                    mutationError = sourceResult.error
                }
            }

            state = .shareUpdated(share: share)
        }
    }

    /// Switch between an invited-people share and a public-link (token) share.
    func setShareeType(share: NKUnifiedShare, anyone: Bool) {
        Task {
            var current = share

            if anyone {
                var removalFailed = false

                for recipient in current.recipients where recipient.class != Self.tokenRecipientClass {
                    guard let updated = await removingRecipient(from: current, recipient: recipient) else {
                        removalFailed = true
                        break
                    }

                    current = updated
                }

                if !removalFailed, !current.recipients.contains(where: { $0.class == Self.tokenRecipientClass }) {
                    let result = await NextcloudKit.shared.addUnifiedShareRecipient(id: current.id, recipientClass: Self.tokenRecipientClass, value: UUID().uuidString, account: account)
                    if let updated = result.share {
                        current = updated
                    } else {
                        mutationError = result.error
                    }
                }
            } else {
                for recipient in current.recipients where recipient.class == Self.tokenRecipientClass {
                    guard let updated = await removingRecipient(from: current, recipient: recipient) else {
                        break
                    }

                    current = updated
                }
            }

            state = .shareUpdated(share: current)
        }
    }

    private func removingRecipient(from share: NKUnifiedShare, recipient: NKUnifiedShareRecipient) async -> NKUnifiedShare? {
        let result = await NextcloudKit.shared.removeUnifiedShareRecipient(id: share.id, recipientClass: recipient.class, value: recipient.value, instance: recipient.instance, account: account)

        if result.share == nil {
            mutationError = result.error
        }

        return result.share
    }

    /// Return the public link, activating the share first so the copied link is live.
    func prepareLinkForCopy(share: NKUnifiedShare) async -> String? {
        if share.state == .active {
            return share.recipients.compactMap({ $0.secret.url }).first
        }

        guard !isPreparingLink else {
            return nil
        }

        isPreparingLink = true
        defer { isPreparingLink = false }

        let result = await NextcloudKit.shared.setUnifiedShareState(id: share.id, state: .active, account: account)
        guard let updated = result.share else {
            mutationError = result.error
            return nil
        }

        state = .shareUpdated(share: updated)
        NotificationCenter.default.post(name: .unifiedShareDidChange, object: nil)
        return updated.recipients.compactMap { $0.secret.url }.first
    }

    func searchRecipients(query: String, share: NKUnifiedShare) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            recipientResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: Self.searchDebounce)

            guard !Task.isCancelled else { return }

            let result = await NextcloudKit.shared.searchUnifiedShareRecipients(query: query, limit: Self.searchLimit, account: account)

            guard !Task.isCancelled else { return }

            recipientResults = (result.recipients ?? []).filter { candidate in
                !share.recipients.contains {
                    $0.class == candidate.class && $0.value == candidate.value && $0.instance == candidate.instance
                }
            }
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
                mutationError = result.error
                return
            }

            state = .shareUpdated(share: share)
        }
    }

    func removeRecipient(share: NKUnifiedShare, recipient: NKUnifiedShareRecipient) {
        Task {
            let result = await NextcloudKit.shared.removeUnifiedShareRecipient(id: share.id, recipientClass: recipient.class, value: recipient.value, instance: recipient.instance, account: account)
            guard let share = result.share else {
                mutationError = result.error
                return
            }

            state = .shareUpdated(share: share)
        }
    }

    func setProperty(share: NKUnifiedShare, propertyClass: String, value: String?) {
        propertyTasks[propertyClass]?.cancel()

        let isClearing = value?.isEmpty ?? true

        if isClearing {
            propertyErrors[propertyClass] = nil
        }

        pendingProperties.insert(propertyClass)

        propertyTasks[propertyClass] = Task {
            let result = await NextcloudKit.shared.setUnifiedShareProperty(id: share.id, propertyClass: propertyClass, value: value, account: account)

            guard !Task.isCancelled else { return }

            pendingProperties.remove(propertyClass)

            guard let share = result.share else {
                if !isClearing {
                    let description = result.error.errorDescription
                    propertyErrors[propertyClass] = description.isEmpty ? String(localized: "Failed to update share.") : description
                }

                return
            }

            propertyErrors[propertyClass] = nil
            state = .shareUpdated(share: share)
        }
    }

    /// Activate the draft (draft → active). This is what persists the share and, for invited
    /// recipients, triggers the server-side notification/email.
    func activate(share: NKUnifiedShare) {
        Task {
            let result = await NextcloudKit.shared.setUnifiedShareState(id: share.id, state: .active, account: account)
            guard let share = result.share else {
                mutationError = result.error
                return
            }

            didActivate = true
            state = .shareUpdated(share: share)
            NotificationCenter.default.post(name: .unifiedShareDidChange, object: nil)
        }
    }

    /// Discard on dismiss only while still a draft (an activated/link share is kept).
    func discardDraftIfNeeded(share: NKUnifiedShare) {
        guard share.state == .draft else {
            return
        }

        deleteShare(share: share)
    }

    func updateRecipientSecret(share: NKUnifiedShare, recipient: NKUnifiedShareRecipient, secret: String) {
        Task {
            let result = await NextcloudKit.shared.setUnifiedShareRecipientSecret(id: share.id, recipientClass: recipient.class, value: recipient.value, secret: secret, instance: recipient.instance, account: account)
            guard let share = result.share else {
                mutationError = result.error
                return
            }

            state = .shareUpdated(share: share)
        }
    }

    /// Mint a fresh server secret and apply it to the recipient (the "regenerate link" action).
    func regenerateRecipientSecret(share: NKUnifiedShare, recipient: NKUnifiedShareRecipient) {
        Task {
            let generated = await NextcloudKit.shared.generateUnifiedShareSecret(account: account)
            guard let secret = generated.secret else {
                mutationError = generated.error
                return
            }

            updateRecipientSecret(share: share, recipient: recipient, secret: secret)
        }
    }
}

