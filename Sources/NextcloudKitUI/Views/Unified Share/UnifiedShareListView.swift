// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

@Observable
public final class CreateUnifiedShareTrigger {
    public var isPresenting = false

    public init() {}
}

/// Lists the existing unified shares for a file, with expandable recipients and swipe-to-delete.
public struct UnifiedShareListView: View {
    let account: String
    let tint: Color
    /// The file's in-server link, forwarded to the editor for invited-people shares.
    let internalLink: String?
    let isDirectory: Bool
    @State private var model: UnifiedShareListModel
    @State private var editing: ShareEditor?
    @State private var shareToDelete: NKUnifiedShare?
    @State private var recipientToDelete: RecipientDeletion?
    @State private var expandedShareIDs: Set<String> = []
    let createTrigger: CreateUnifiedShareTrigger
    @Environment(\.colorScheme) private var colorScheme

    public init(account: String, sourceId: String? = nil, internalLink: String? = nil, isDirectory: Bool = false, tint: Color = .accentColor, createTrigger: CreateUnifiedShareTrigger = CreateUnifiedShareTrigger(), onError: ((NKError) -> Void)? = nil) {
        self.account = account
        self.tint = tint
        self.internalLink = internalLink
        self.isDirectory = isDirectory
        self.createTrigger = createTrigger
        model = UnifiedShareListModel(account: account, sourceId: sourceId, onError: onError)
    }

    init(model: UnifiedShareListModel, isDirectory: Bool = false, tint: Color = .accentColor, initiallyExpandedShareIDs: Set<String> = []) {
        self.account = model.account
        self.tint = tint
        self.internalLink = nil
        self.isDirectory = isDirectory
        self.createTrigger = CreateUnifiedShareTrigger()
        self.model = model
        _expandedShareIDs = State(initialValue: initiallyExpandedShareIDs)
    }

    public var body: some View {
        @Bindable var createTrigger = createTrigger

        content
            .task {
                if case .loading = model.state {
                    model.load()
                }
            }
            .sheet(item: $editing, onDismiss: {
                Task { await model.refresh() }
            }) { editor in
                NavigationStack {
                    if let recipient = editor.recipient {
                        UnifiedShareEditView(account: account, share: editor.share, recipient: recipient)
                    } else {
                        UnifiedShareEditView(
                            account: account,
                            share: editor.share,
                            internalLink: internalLink,
                            expandSettings: editor.expandSettings,
                            forceCustomPermissions: editor.forceCustomPermissions
                        )
                    }
                }
            }
            .sheet(isPresented: $createTrigger.isPresenting, onDismiss: {
                Task { await model.refresh() }
            }) {
                NavigationStack {
                    UnifiedShareEditView(account: account, sourceId: model.sourceId, internalLink: internalLink)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let error):
            ContentUnavailableView {
                Label(String(localized: "Couldn't load shares"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button(String(localized: "Retry")) {
                    model.load()
                }
            }

        case .loaded(let shares):
            List {
                ForEach(shares) { share in
                    shareContainer(share)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                shareToDelete = share
                            } label: {
                                Label(String(localized: "Delete"), systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .confirmationDialog(
                            String(localized: "Delete share?"),
                            isPresented: Binding(
                                get: { shareToDelete?.id == share.id },
                                set: { if !$0 { shareToDelete = nil } }
                            ),
                            titleVisibility: .visible
                        ) {
                            Button(String(localized: "Delete"), role: .destructive) {
                                expandedShareIDs.remove(share.id)
                                model.delete(share: share)
                                shareToDelete = nil
                            }

                            Button(String(localized: "Cancel"), role: .cancel) {
                                shareToDelete = nil
                            }
                        } message: {
                            Text(String(localized: "This share will be permanently removed."))
                        }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(.background)
            .refreshable {
                await model.refresh()
            }
            .overlay {
                if shares.isEmpty {
                    ContentUnavailableView {
                        Label("Not Shared Yet", systemImage: "person.badge.plus.fill")
                    } actions: {
                        Button(isDirectory ? String(localized: "Share Folder") : String(localized: "Share File")) {
                            createTrigger.isPresenting = true
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func shareContainer(_ share: NKUnifiedShare) -> some View {
        if share.recipients.count > 1 {
            let isExpanded = expansionBinding(for: share)

            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(Array(share.recipients.enumerated()), id: \.offset) { _, recipient in
                    recipientRow(recipient, in: share)
                }
            } label: {
                HStack(spacing: 8) {
                    shareRow(share, showsAvatars: !isExpanded.wrappedValue)

                    Button {
                        withAnimation {
                            isExpanded.wrappedValue.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded.wrappedValue ? String(localized: "Hide recipients") : String(localized: "Show recipients"))

                    shareMenu(share)
                }
            }
            .disclosureGroupStyle(ShareDisclosureGroupStyle())
        } else {
            HStack(spacing: 8) {
                shareRow(share)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editing = ShareEditor(share: share, recipient: share.recipients.first)
                    }

                shareMenu(share)
            }
        }
    }

    private func shareRow(_ share: NKUnifiedShare, showsAvatars: Bool = true) -> some View {
        HStack(spacing: 12) {
            if showsAvatars {
                recipientAvatars(share.recipients)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(share.recipients.count == 1 ? (share.recipients.first?.displayName ?? "") : recipientSummary(share.recipients))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let recipient = share.recipients.first, share.recipients.count == 1 {
                    recipientPresetChip(recipient, in: share)
                }
            }

            Spacer()
        }
    }

    // MARK: - Row content

    @ViewBuilder
    private func recipientAvatar(_ recipient: NKUnifiedShareRecipient) -> some View {
        if let icon = recipient.icon,
           let urlString = iconURL(icon),
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(.quaternary)
            }
        } else if recipient.secret.updatable {
            linkIcon
        } else {
            Circle()
                .fill(.quaternary)
                .overlay {
                    Text(recipient.displayName.prefix(1).uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    @ViewBuilder
    private func recipientAvatars(_ recipients: [NKUnifiedShareRecipient]) -> some View {
        let visibleRecipients = Array(recipients.prefix(3))

        if visibleRecipients.isEmpty {
            linkIcon
                .frame(width: 32, height: 32)
        } else {
            HStack(spacing: -10) {
                ForEach(Array(visibleRecipients.enumerated()), id: \.offset) { index, recipient in
                    recipientAvatar(recipient)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(.background, lineWidth: 2)
                        }
                        .zIndex(Double(index))
                }
            }
        }
    }

    private var linkIcon: some View {
        Circle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
    }

    private func recipientRow(_ recipient: NKUnifiedShareRecipient, in share: NKUnifiedShare) -> some View {
        HStack(spacing: 12) {
            recipientAvatar(recipient)
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(recipient.displayName)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                recipientPresetChip(recipient, in: share)
            }

            Spacer()

            recipientMenu(recipient, in: share)
        }
        .background {
            Button {
                editing = ShareEditor(share: share, recipient: recipient)
            } label: {
                Color.clear
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recipient.displayName)
        }
    }

    private func recipientPresetChip(_ recipient: NKUnifiedShareRecipient, in share: NKUnifiedShare) -> some View {
        Menu {
            ForEach(model.applicablePresets(recipient), id: \.class) { preset in
                Button(preset.displayName) {
                    model.setPermissionPreset(share: share, recipient: recipient, presetClass: preset.class)
                }
            }

            Divider()

            Button(String(localized: "Can…")) {
                editing = ShareEditor(share: share, recipient: recipient)
            }
        } label: {
            HStack(spacing: 2) {
                Text(recipientPresetLabel(recipient))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func recipientMenu(_ recipient: NKUnifiedShareRecipient, in share: NKUnifiedShare) -> some View {
        let deletion = RecipientDeletion(share: share, recipient: recipient)

        return Menu {
            Button {
                editing = ShareEditor(share: share, recipient: recipient)
            } label: {
                Label(String(localized: "Edit"), systemImage: "pencil")
            }

            // Sending email is intentionally omitted until a recipient-specific flow is available.

            Button(role: .destructive) {
                recipientToDelete = deletion
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
            .tint(.red)
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .tint(.primary)
        .confirmationDialog(
            String(localized: "Delete recipient?"),
            isPresented: Binding(
                get: { recipientToDelete?.id == deletion.id },
                set: { if !$0 { recipientToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                model.remove(recipient: recipient, from: share)
                recipientToDelete = nil
            }

            Button(String(localized: "Cancel"), role: .cancel) {
                recipientToDelete = nil
            }
        } message: {
            Text(String(localized: "This recipient will be removed from the share."))
        }
    }

    private func shareMenu(_ share: NKUnifiedShare) -> some View {
        Menu {
            Button {
                editing = ShareEditor(share: share)
            } label: {
                Label(String(localized: "Edit"), systemImage: "pencil")
            }

            // Sending email is intentionally omitted until the correct flow is available.

            Button(role: .destructive) {
                shareToDelete = share
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
            .tint(.red)
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .tint(.primary)
    }

    private func expansionBinding(for share: NKUnifiedShare) -> Binding<Bool> {
        Binding(
            get: { expandedShareIDs.contains(share.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedShareIDs.insert(share.id)
                } else {
                    expandedShareIDs.remove(share.id)
                }
            }
        )
    }

    private func recipientSummary(_ recipients: [NKUnifiedShareRecipient]) -> String {
        let groupCount = recipients.filter(isGroup).count
        let linkCount = recipients.filter(isLink).count
        let peopleCount = recipients.count - groupCount - linkCount
        var components: [String] = []

        if peopleCount == 1 {
            components.append(String(localized: "1 person"))
        } else if peopleCount > 1 {
            components.append(String(localized: "\(peopleCount) people"))
        }

        if groupCount == 1 {
            components.append(String(localized: "1 group"))
        } else if groupCount > 1 {
            components.append(String(localized: "\(groupCount) groups"))
        }

        if linkCount == 1 {
            components.append(String(localized: "1 link"))
        } else if linkCount > 1 {
            components.append(String(localized: "\(linkCount) links"))
        }

        return components.isEmpty ? String(localized: "No recipients") : components.joined(separator: ", ")
    }

    private func recipientPresetLabel(_ recipient: NKUnifiedShareRecipient) -> String {
        guard !recipient.permissions.isEmpty else {
            return String(localized: "Can…")
        }

        if let preset = model.applicablePresets(recipient).first(where: { preset in
            recipient.permissions.allSatisfy { permission in
                permission.enabled == permission.presets.contains(preset.class)
            }
        }) {
            return preset.displayName
        }

        return String(localized: "Can…")
    }

    // MARK: - Helpers

    private func isGroup(_ recipient: NKUnifiedShareRecipient) -> Bool {
        recipient.class.range(of: "group", options: .caseInsensitive) != nil
    }

    private func isLink(_ recipient: NKUnifiedShareRecipient) -> Bool {
        recipient.secret.updatable
    }

    private func iconURL(_ icon: NKUnifiedShareIcon) -> String? {
        (colorScheme == .dark ? icon.dark : icon.light) ?? icon.light ?? icon.dark
    }
}

private struct ShareEditor: Identifiable {
    let share: NKUnifiedShare
    var recipient: NKUnifiedShareRecipient?
    var expandSettings = false
    var forceCustomPermissions = false
    var id: String { share.id }

    init(share: NKUnifiedShare,
         recipient: NKUnifiedShareRecipient? = nil,
         expandSettings: Bool = false,
         forceCustomPermissions: Bool = false) {
        self.share = share
        self.recipient = recipient
        self.expandSettings = expandSettings
        self.forceCustomPermissions = forceCustomPermissions
    }
}

private struct RecipientDeletion: Identifiable {
    let share: NKUnifiedShare
    let recipient: NKUnifiedShareRecipient

    var id: String {
        [share.id, recipient.class, recipient.value, recipient.instance ?? ""].joined(separator: "|")
    }
}

private struct ShareDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.label

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 20)
                    .padding(.top, 4)
            }
        }
    }
}

#if DEBUG

private extension NKUnifiedShare {
    static func preview(id: String, recipients: [NKUnifiedShareRecipient]) -> NKUnifiedShare {
        let template = NKUnifiedShare.mock

        return NKUnifiedShare(
            id: id,
            owner: template.owner,
            lastUpdated: template.lastUpdated,
            state: template.state,
            userStatus: template.userStatus,
            sources: template.sources,
            recipients: recipients,
            properties: template.properties,
            permissions: template.permissions,
            permissionPreset: template.permissionPreset
        )
    }
}

#Preview {
    let recipients: [NKUnifiedShareRecipient] = .mocks
    let shares = [
        NKUnifiedShare.preview(id: "preview-4", recipients: recipients),
        NKUnifiedShare.preview(id: "preview-2", recipients: Array(recipients.prefix(2))),
        NKUnifiedShare.preview(id: "preview-1", recipients: Array(recipients.prefix(1)))
    ]

    NavigationStack {
        UnifiedShareListView(
            model: UnifiedShareListModel(
                account: "",
                state: .loaded(shares),
                permissionPresets: [
                    NKUnifiedSharePermissionPreset(class: "viewer", displayName: "Can view"),
                    NKUnifiedSharePermissionPreset(class: "editor", displayName: "Can edit")
                ]
            ),
            initiallyExpandedShareIDs: ["preview-4", "preview-2"]
        )
        .navigationTitle("Shares")
    }
}

#endif
