// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

/// Lists the existing unified shares for a file, with tap-to-edit and swipe-to-delete.
public struct UnifiedShareListView: View {
    let fileName: String
    let account: String
    /// Brand/accent color (the app passes NCBrandColor); used for the chip and ⋯ button.
    let tint: Color
    @State private var model: UnifiedShareListModel
    @State private var editing: ShareEditor?
    @State private var shareToDelete: NKUnifiedShare?
    @Environment(\.colorScheme) private var colorScheme

    public init(fileName: String, account: String, sourceId: String? = nil, tint: Color = .accentColor) {
        self.fileName = fileName
        self.account = account
        self.tint = tint
        model = UnifiedShareListModel(account: account, sourceId: sourceId)
    }

    public var body: some View {
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
                    UnifiedShareEditView(fileName: fileName, account: account, share: editor.share, expandSettings: editor.expandSettings)
                }
            }
            // A share created/activated from the "+" modal (outside this view) refreshes the list.
            .onReceive(NotificationCenter.default.publisher(for: .unifiedShareDidChange)) { _ in
                Task { await model.refresh() }
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
                    shareRow(share, allShares: shares)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                shareToDelete = share
                            } label: {
                                Label(String(localized: "Delete"), systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await model.refresh()
            }
            .overlay {
                if shares.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No shares yet"),
                        systemImage: "person.2.slash",
                        description: Text(String(localized: "Use the + button to share \(fileName)."))
                    )
                }
            }
        }
    }

    private func shareRow(_ share: NKUnifiedShare, allShares: [NKUnifiedShare]) -> some View {
        HStack(spacing: 12) {
            shareIcon(share)
                .frame(width: 32, height: 32)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(headline(share, in: allShares))
                    .foregroundStyle(.primary)

                presetChip(share)
            }

            Spacer()

            overflowMenu(share)
                .confirmationDialog(
                    String(localized: "Delete share?"),
                    isPresented: Binding(
                        get: { shareToDelete?.id == share.id },
                        set: { if !$0 { shareToDelete = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "Delete"), role: .destructive) {
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

    // MARK: - Row content

    @ViewBuilder
    private func shareIcon(_ share: NKUnifiedShare) -> some View {
        if let icon = share.recipients.first?.icon,
           let urlString = iconURL(icon),
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                letterAvatar(share)
            }
        } else {
            letterAvatar(share)
        }
    }

    /// Colored circle with the recipient's initial — the native stand-in for the server avatar.
    private func letterAvatar(_ share: NKUnifiedShare) -> some View {
        let name = share.recipients.first?.displayName ?? ""
        let initial = name.first.map { String($0).uppercased() } ?? "?"

        return Circle()
            .fill(avatarColor(for: name.isEmpty ? initial : name))
            .overlay {
                Text(initial)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private func avatarColor(for string: String) -> Color {
        let hash = string.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Color(hue: Double(hash % 360) / 360.0, saturation: 0.55, brightness: 0.55)
    }

    private func headline(_ share: NKUnifiedShare, in shares: [NKUnifiedShare]) -> String {
        guard isLink(share) else {
            return peopleRecipients(share).first?.displayName ?? String(localized: "Share")
        }

        if let label = label(share) {
            return label
        }

        let links = shares.filter { isLink($0) }
        if links.count <= 1 {
            return String(localized: "Share link")
        }

        let position = (links.sorted { $0.lastUpdated < $1.lastUpdated }.firstIndex { $0.id == share.id } ?? 0) + 1
        return String(localized: "Share link (\(position))")
    }

    /// The preset chip — a menu of the applicable presets plus "Custom permissions" (opens the editor).
    private func presetChip(_ share: NKUnifiedShare) -> some View {
        Menu {
            ForEach(model.applicablePresets(share), id: \.class) { preset in
                Button(preset.displayName) {
                    model.setPermissionPreset(share: share, presetClass: preset.class)
                }
            }

            Divider()

            Button(String(localized: "Can…")) {
                editing = ShareEditor(share: share)
            }
        } label: {
            HStack(spacing: 2) {
                Text(presetLabel(share))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func overflowMenu(_ share: NKUnifiedShare) -> some View {
        Menu {
            Button {
                editing = ShareEditor(share: share)
            } label: {
                Label(String(localized: "Edit"), systemImage: "pencil")
            }

            Button {
                editing = ShareEditor(share: share, expandSettings: true)
            } label: {
                Label(String(localized: "Send email"), systemImage: "envelope")
            }

            Button(role: .destructive) {
                shareToDelete = share
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
            .tint(.red)
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .tint(.primary)
    }

    private func presetLabel(_ share: NKUnifiedShare) -> String {
        if let presetClass = share.permissionPreset,
           let preset = model.permissionPresets.first(where: { $0.class == presetClass }) {
            return preset.displayName
        }

        return String(localized: "Can…")
    }

    // MARK: - Helpers

    private func isLink(_ share: NKUnifiedShare) -> Bool {
        share.recipients.contains { $0.secret.updatable }
    }

    private func peopleRecipients(_ share: NKUnifiedShare) -> [NKUnifiedShareRecipient] {
        share.recipients.filter { !$0.secret.updatable }
    }

    /// A property whose class contains "label" carries the link's custom label.
    private func label(_ share: NKUnifiedShare) -> String? {
        let value = share.properties.first { $0.class.range(of: "label", options: .caseInsensitive) != nil }?.value
        guard let value, !value.isEmpty else {
            return nil
        }

        return value
    }

    private func iconURL(_ icon: NKUnifiedShareIcon) -> String? {
        (colorScheme == .dark ? icon.dark : icon.light) ?? icon.light ?? icon.dark
    }
}

private struct ShareEditor: Identifiable {
    let share: NKUnifiedShare
    var expandSettings = false
    var id: String { share.id }
}
