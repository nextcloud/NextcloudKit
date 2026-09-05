// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit
#if canImport(UIKit)
import UIKit
#endif

/// View used for Unified Sharing.
public struct UnifiedShareEditView: View {
    /// Editing an existing share (vs composing a new draft): the audience is fixed.
    let isEditingExisting: Bool
    /// When set, the editor changes permissions only for this recipient.
    @State private var selectedRecipient: NKUnifiedShareRecipient?
    /// The file's in-server link, copied for invited-people shares.
    let internalLink: String?
    @State private var model: UnifiedShareEditModel

    @State private var shareeType: ShareeType = .invited
    @State private var permissionSelection: PermissionSelection = .unset
    @State private var isSettingsExpanded = false
    @State private var recipients = ""
    /// The exact server object selected when the destructive action is tapped.
    /// Keeping it stable prevents an asynchronous refresh from changing a recipient deletion
    /// into a whole-share deletion while the confirmation dialog is open.
    @State private var deletionTarget: EditorDeletionTarget?
    @State private var recipientToDelete: NKUnifiedShareRecipient?
    /// Hides the audience-dependent rows while a switch is running.
    @State private var showsRows = true
    @State private var showsCopied = false
    @State private var copiedTask: Task<Void, Never>?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    public init(account: String, sourceId: String? = nil, internalLink: String? = nil) {
        self.isEditingExisting = false
        self.internalLink = internalLink
        model = UnifiedShareEditModel(account: account, sourceId: sourceId)
        _selectedRecipient = State(initialValue: nil)
    }

    /// Open the editor on an existing share (from the list).
    public init(account: String, share: NKUnifiedShare, internalLink: String? = nil, expandSettings: Bool = false, forceCustomPermissions: Bool = false) {
        self.isEditingExisting = true
        self.internalLink = internalLink
        model = UnifiedShareEditModel(account: account, existingShare: share)
        _selectedRecipient = State(initialValue: nil)
        _shareeType = State(initialValue: share.recipients.contains { $0.class == UnifiedShareEditModel.tokenRecipientClass } ? .anyone : .invited)
        _isSettingsExpanded = State(initialValue: expandSettings)
        _permissionSelection = State(initialValue: forceCustomPermissions ? .custom : .unset)
    }

    init(account: String,
         share: NKUnifiedShare,
         internalLink: String?,
         expandSettings: Bool,
         forceCustomPermissions: Bool,
         permissionPresets: [NKUnifiedSharePermissionPreset]) {
        self.isEditingExisting = true
        self.internalLink = internalLink
        model = UnifiedShareEditModel(account: account, existingShare: share, permissionPresets: permissionPresets)
        _selectedRecipient = State(initialValue: nil)
        _shareeType = State(initialValue: share.recipients.contains {
            $0.class == UnifiedShareEditModel.tokenRecipientClass
        } ? .anyone : .invited)
        _isSettingsExpanded = State(initialValue: expandSettings)
        _permissionSelection = State(initialValue: forceCustomPermissions ? .custom : .unset)
    }

    /// Open the permissions editor for one recipient of an existing share.
    public init(account: String,
                share: NKUnifiedShare,
                recipient: NKUnifiedShareRecipient,
                internalLink: String? = nil) {
        self.isEditingExisting = true
        self.internalLink = internalLink
        model = UnifiedShareEditModel(account: account, existingShare: share)
        _selectedRecipient = State(initialValue: recipient)
        _shareeType = State(initialValue: .invited)
    }

    init(account: String,
         share: NKUnifiedShare,
         recipient: NKUnifiedShareRecipient,
         internalLink: String?,
         permissionPresets: [NKUnifiedSharePermissionPreset]) {
        self.isEditingExisting = true
        self.internalLink = internalLink
        model = UnifiedShareEditModel(account: account, existingShare: share, permissionPresets: permissionPresets)
        _selectedRecipient = State(initialValue: recipient)
        _shareeType = State(initialValue: .invited)
    }

    init(model: UnifiedShareEditModel) {
        self.isEditingExisting = false
        self.internalLink = nil
        self.model = model
        _selectedRecipient = State(initialValue: nil)
    }

    public var body: some View {
        ZStack {
            switch model.state {
            case .loading:
                ProgressView()
            case .shareUpdated(let share):

                    Form {
                        // The audience is only selectable for a new draft; an existing share's is fixed.
                        if !isEditingExisting {
                            shareeTypePicker(share: share)
                                .disabled(model.isSwitchingAudience)
                        }

                        if showsRows, shareeType == .invited {
                            if selectedRecipient == nil, !peopleRecipients(share).isEmpty {
                                recipientPills(share: share)
                                    .listRowSeparator(.hidden)
                            }

                            if selectedRecipient == nil {
                                TextField(
                                    String(localized: "Add people"),
                                    text: $recipients
                                )
                                .onChange(of: recipients) {
                                    model.searchRecipients(query: recipients, share: share)
                                }
                                // Publish the field's frame so the dropdown can be drawn outside the Form.
                                .anchorPreference(key: AddPeopleFieldAnchorKey.self, value: .bounds) { $0 }
                            }
                        }

                        if showsRows {
                            if let recipient = currentSelectedRecipient(in: share) {
                                recipientPermissionField(share: share, recipient: recipient)
                            } else {
                                permissionField(share: share)
                            }

                            ForEach(basicProperties(share), id: \.class) { property in
                                PropertyRow(property: property, error: model.propertyErrors[property.class]) { value in
                                    model.setProperty(share: share, propertyClass: property.class, value: value)
                                }
                                .id("\(property.class)|\(model.propertyResetRevisions[property.class] ?? 0)")
                            }

                            settingsRow(share: share)
                        }

                        if !model.isSwitchingAudience, isEditingExisting || structuralCanSend(share) {
                            actionButtons(share: share)
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: model.isSwitchingAudience) {
                        showsRows = !model.isSwitchingAudience
                    }
                    .onChange(of: model.permissionResetRevision) {
                        permissionSelection = .unset
                    }
                    // An overlay, not a Form row: conditional row insertion driven by the
                    // observable flag stops rendering after the first cycle.
                    .overlay {
                        if model.showsSwitchSpinner {
                            ProgressView()
                        }
                    }
                    .onDisappear {
                        model.discardDraftIfNeeded(share: share)
                    }
                    .onChange(of: model.didActivate) {
                        if model.didActivate {
                            dismiss()
                        }
                    }
                    // Draw the dropdown above the Form, anchored just beneath the field, so the
                    // Form's row clipping can't cut it off.
                    .overlayPreferenceValue(AddPeopleFieldAnchorKey.self) { anchor in
                        GeometryReader { proxy in
                            if let anchor, !model.recipientResults.isEmpty {
                                let frame = proxy[anchor]

                                recipientDropdown(share: share)
                                    .frame(width: frame.width)
                                    .offset(x: frame.minX, y: frame.maxY + 4)
                            }
                        }
                    }

            case .error:
                Text(String(localized: "Could not create share, try again later"))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(navigationTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .alert(
            String(localized: "Failed to update share."),
            isPresented: Binding(
                get: { model.mutationError != nil },
                set: { if !$0 { model.mutationError = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            if let error = model.mutationError {
                Text(error.errorDescription)
            }
        }
        .task {
            guard !isPreview else {
                return
            }

            if case .loading = model.state {
                model.createShare()
            }

            if model.permissionPresets.isEmpty {
                model.loadCapabilities()
            }
        }
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var navigationTitle: String {
        guard case .shareUpdated(let share) = model.state else {
            return ""
        }

        let name = share.sources.first?.displayName ?? "..."
        return String(localized: "Share \"\(name)\"")
    }

    @ViewBuilder
    private func recipientPermissionField(share: NKUnifiedShare, recipient: NKUnifiedShareRecipient) -> some View {
        Picker(recipient.displayName, selection: Binding(
            get: {
                isRecipientCustomSelected(recipient, in: share)
                    ? Self.customTag
                    : (selectedRecipientPresetClass(recipient, in: share) ?? Self.customTag)
            },
            set: { tag in
                if tag == Self.customTag {
                    permissionSelection = .custom
                } else {
                    permissionSelection = .preset(tag)
                    model.setRecipientPermissionPreset(share: share, recipient: recipient, presetClass: tag)
                }
            }
        )) {
            ForEach(applicablePresets(recipient, in: share), id: \.class) { preset in
                Text(preset.displayName)
                    .tag(preset.class)
            }

            Text(String(localized: "Can…"))
                .tag(Self.customTag)
        }
        .pickerStyle(.menu)
        .disabled(model.isUpdatingPermissions)

        if isRecipientCustomSelected(recipient, in: share) {
            ForEach(recipient.effectivePermissions(in: share), id: \.class) { permission in
                PermissionToggleRow(permission: permission) { enabled in
                    model.setRecipientPermission(
                        share: share,
                        recipient: recipient,
                        permissionClass: permission.class,
                        enabled: enabled
                    )
                }
                .id("\(permission.class)|\(permission.enabled)|\(model.permissionResetRevision)")
                .disabled(model.isUpdatingPermissions)
            }
        }
    }

    private func currentSelectedRecipient(in share: NKUnifiedShare) -> NKUnifiedShareRecipient? {
        guard let selectedRecipient else {
            return nil
        }

        return share.recipients.first(where: {
            $0.unifiedShareIdentity == selectedRecipient.unifiedShareIdentity
        })
    }

    private func shareeTypePicker(share: NKUnifiedShare) -> some View {
        Picker("", selection: $shareeType) {
            Text(String(localized: "Invited People"))
                .tag(ShareeType.invited)

            Text(String(localized: "Anyone"))
                .tag(ShareeType.anyone)
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)
        .onChange(of: shareeType) {
            model.setShareeType(share: share, anyone: shareeType == .anyone)
        }
    }

    @ViewBuilder
    private func permissionField(share: NKUnifiedShare) -> some View {
        Picker(String(localized: "Participants"), selection: Binding(
            get: { isCustomSelected(share) ? Self.customTag : (selectedPresetClass(share) ?? Self.customTag) },
            set: { tag in
                if tag == Self.customTag {
                    permissionSelection = .custom
                } else {
                    permissionSelection = .preset(tag)
                    model.setPermissionPreset(share: share, presetClass: tag)
                }
            }
        )) {
            ForEach(applicablePresets(share), id: \.class) { preset in
                Text(preset.displayName)
                    .tag(preset.class)
            }

            // Custom: reveals the per-permission toggles below. Client-side only, no request.
            Text(String(localized: "Can…"))
                .tag(Self.customTag)
        }
        .pickerStyle(.menu)
        .disabled(model.isUpdatingPermissions)

        if isCustomSelected(share) {
            ForEach(share.permissions, id: \.class) { permission in
                PermissionToggleRow(permission: permission) { enabled in
                    model.setPermission(share: share, permissionClass: permission.class, enabled: enabled)
                }
                // Re-seed the toggle whenever the server's enabled value changes (e.g. after a
                // preset like "Can edit" recomputes the permissions), not just on first render.
                .id("\(permission.class)|\(permission.enabled)|\(model.permissionResetRevision)")
                .disabled(model.isUpdatingPermissions)
            }
        }
    }

    private static let customTag = "__nk_custom_permissions__"
    private static let rolePropertyClass = "role"

    /// Presets from the capability, narrowed to those the share's permissions reference.
    private func applicablePresets(_ share: NKUnifiedShare) -> [NKUnifiedSharePermissionPreset] {
        let applicable = Set(share.permissions.flatMap { $0.presets })
        return model.permissionPresets.filter { applicable.contains($0.class) }
    }

    private func applicablePresets(_ recipient: NKUnifiedShareRecipient, in share: NKUnifiedShare) -> [NKUnifiedSharePermissionPreset] {
        let applicable = Set(recipient.effectivePermissions(in: share).flatMap { $0.presets })
        return model.permissionPresets.filter { applicable.contains($0.class) }
    }

    /// The effective preset class: the user's pick, else the share's server-side preset.
    private func selectedPresetClass(_ share: NKUnifiedShare) -> String? {
        switch permissionSelection {
        case .unset: return share.permissionPreset
        case .custom: return nil
        case .preset(let presetClass): return presetClass
        }
    }

    /// Custom mode (toggles shown) when there's no preset, or the preset isn't a known one.
    private func isCustomSelected(_ share: NKUnifiedShare) -> Bool {
        guard let presetClass = selectedPresetClass(share) else {
            return true
        }

        return !applicablePresets(share).contains { $0.class == presetClass }
    }

    private func selectedRecipientPresetClass(_ recipient: NKUnifiedShareRecipient, in share: NKUnifiedShare) -> String? {
        switch permissionSelection {
        case .unset:
            return applicablePresets(recipient, in: share).first { preset in
                recipient.effectivePermissions(in: share).allSatisfy { permission in
                    permission.enabled == permission.presets.contains(preset.class)
                }
            }?.class
        case .custom:
            return nil
        case .preset(let presetClass):
            return presetClass
        }
    }

    private func isRecipientCustomSelected(_ recipient: NKUnifiedShareRecipient, in share: NKUnifiedShare) -> Bool {
        guard let presetClass = selectedRecipientPresetClass(recipient, in: share) else {
            return true
        }

        return !applicablePresets(recipient, in: share).contains { $0.class == presetClass }
    }

    /// Advanced properties + editable link tokens live behind the disclosure; basic properties inline.
    @ViewBuilder
    private func settingsRow(share: NKUnifiedShare) -> some View {
        if !advancedProperties(share).isEmpty || !customLinkRecipients(share).isEmpty {
            DisclosureGroup(isExpanded: $isSettingsExpanded) {
                ForEach(advancedProperties(share), id: \.class) { property in
                    PropertyRow(property: property, error: model.propertyErrors[property.class]) { value in
                        model.setProperty(share: share, propertyClass: property.class, value: value)
                    }
                    .id("\(property.class)|\(model.propertyResetRevisions[property.class] ?? 0)")
                }

                customLinkRows(share: share)
            } label: {
                Text(String(localized: "Settings"))
            }
        }
    }

    private func deleteAction(share: NKUnifiedShare) -> some View {
        let recipient = currentSelectedRecipient(in: share)

        return Button(role: .destructive) {
            if let recipient {
                deletionTarget = .recipient(shareID: share.id, recipient: recipient)
            } else {
                deletionTarget = .share(id: share.id)
            }
        } label: {
            Text(recipient == nil ? String(localized: "Delete share") : String(localized: "Delete recipient"))
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(selectedRecipient != nil && recipient == nil)
        .confirmationDialog(
            deletionTarget?.isRecipient == true ? String(localized: "Delete recipient?") : String(localized: "Delete share?"),
            isPresented: Binding(
                get: { deletionTarget != nil },
                set: { if !$0 { deletionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                switch deletionTarget {
                case .recipient(let shareID, let recipient) where share.id == shareID:
                    model.removeRecipient(share: share, recipient: recipient) {
                        dismiss()
                    }
                case .share(let shareID) where share.id == shareID:
                    model.deleteShare(share: share) {
                        dismiss()
                    }
                default:
                    // The share changed while the dialog was open: do not delete anything.
                    break
                }

                deletionTarget = nil
            }

            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            if deletionTarget?.isRecipient == true {
                Text(String(localized: "This recipient will be removed from the share."))
            } else {
                Text(String(localized: "This share will be permanently removed."))
            }
        }
    }

    @ViewBuilder
    private func customLinkRows(share: NKUnifiedShare) -> some View {
        if !customLinkRecipients(share).isEmpty {
            ForEach(customLinkRecipients(share), id: \.unifiedShareIdentity) { recipient in
                CustomLinkRow(
                    recipient: recipient,
                    onCommit: { token in model.updateRecipientSecret(share: share, recipient: recipient, secret: token) },
                    onRegenerate: { model.regenerateRecipientSecret(share: share, recipient: recipient) }
                )
                // Re-seed the row's local token whenever the server-side secret changes.
                .id("\(recipient.secret.value ?? "")|\(model.recipientSecretResetRevision(share: share, recipient: recipient))")
            }

            Text(String(localized: "The link can be changed to be easy to remember, but do not set it to something that is easy to guess."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
        }
    }

    private func basicProperties(_ share: NKUnifiedShare) -> [NKUnifiedShareProperty] {
        share.properties
            // "role" is a share-wide property and would be misleading in the recipient editor.
            // Recipient access is edited through the dedicated permission controls above.
            .filter { !$0.advanced && $0.class != Self.rolePropertyClass }
            .sorted { $0.priority < $1.priority }
    }

    private func advancedProperties(_ share: NKUnifiedShare) -> [NKUnifiedShareProperty] {
        share.properties
            .filter { $0.advanced && $0.class != Self.rolePropertyClass }
            .sorted { $0.priority < $1.priority }
    }

    /// Recipients whose secret can be edited — i.e. custom/private links.
    private func customLinkRecipients(_ share: NKUnifiedShare) -> [NKUnifiedShareRecipient] {
        share.recipients.filter { $0.secret.updatable }
    }

    private func recipientDropdown(share: NKUnifiedShare) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.recipientResults.enumerated()), id: \.element.unifiedShareIdentity) { index, recipient in
                    Button {
                        recipients = ""
                        model.addRecipient(share: share, recipient: recipient) { _ in
                            permissionSelection = .unset
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if let icon = recipient.icon {
                                recipientIcon(icon)
                            }

                            Text(recipient.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < model.recipientResults.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .frame(height: dropdownHeight)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
        .shadow(radius: 4, y: 2)
    }

    /// Height of the suggestions dropdown: one row each, capped so it stays a dropdown.
    private var dropdownHeight: CGFloat {
        min(CGFloat(model.recipientResults.count) * 44, 220)
    }

    @ViewBuilder
    private func recipientIcon(_ icon: NKUnifiedShareIcon) -> some View {
        if let urlString = (colorScheme == .dark ? icon.dark : icon.light) ?? icon.light ?? icon.dark,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
        }
    }

    private func recipientPills(share: NKUnifiedShare) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(peopleRecipients(share), id: \.unifiedShareIdentity) { recipient in
                recipientPill(recipient, share: share)
            }
        }
    }

    private func peopleRecipients(_ share: NKUnifiedShare) -> [NKUnifiedShareRecipient] {
        share.recipients.filter { !$0.secret.updatable }
    }

    private func recipientPill(_ recipient: NKUnifiedShareRecipient, share: NKUnifiedShare) -> some View {
        HStack(spacing: 6) {
            recipientAvatar(recipient)

            Text(recipient.displayName)
                .lineLimit(1)

            Button {
                recipientToDelete = recipient
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Delete recipient"))
            .confirmationDialog(
                String(localized: "Delete recipient?"),
                isPresented: Binding(
                    get: {
                        guard let recipientToDelete else { return false }
                        return sameRecipient(recipientToDelete, recipient)
                    },
                    set: { if !$0 { recipientToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete"), role: .destructive) {
                    model.removeRecipient(share: share, recipient: recipient)
                    recipientToDelete = nil
                }

                Button(String(localized: "Cancel"), role: .cancel) {
                    recipientToDelete = nil
                }
            } message: {
                Text(String(localized: "This recipient will be removed from the share."))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.quaternary))
        .overlay(Capsule().stroke(.tertiary, lineWidth: 0.5))
    }

    private func sameRecipient(_ lhs: NKUnifiedShareRecipient, _ rhs: NKUnifiedShareRecipient) -> Bool {
        lhs.unifiedShareIdentity == rhs.unifiedShareIdentity
    }

    /// The recipient's URL avatar when available, otherwise a circle with its initial.
    @ViewBuilder
    private func recipientAvatar(_ recipient: NKUnifiedShareRecipient) -> some View {
        if let icon = recipient.icon, icon.light != nil || icon.dark != nil {
            recipientIcon(icon)
        } else {
            Circle()
                .fill(.quaternary)
                .frame(width: 24, height: 24)
                .overlay {
                    Text(recipient.displayName.prefix(1).uppercased())
                        .font(.caption)
                }
        }
    }

    private func actionButtons(share: NKUnifiedShare) -> some View {
        HStack(spacing: 16) {
            copyButton(share: share)

            if isEditingExisting {
                Spacer()

                deleteAction(share: share)
            } else {
                Spacer()

                Button(sendLabel) {
                    model.activate(share: share)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSend(share))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    /// Anyone: copy the public link, activating the draft to mint it if needed.
    /// Invited: copy the internal link — never activates (that would send the share).
    @ViewBuilder
    private func copyButton(share: NKUnifiedShare) -> some View {
        if shareeType == .anyone {
            Button {
                Task {
                    if let link = await model.prepareLinkForCopy(share: share) {
                        copyToPasteboard(link)
                        flashCopied()
                    }
                }
            } label: {
                if model.isPreparingLink {
                    ProgressView()
                } else {
                    Text(showsCopied ? String(localized: "Copied") : String(localized: "Copy public link"))
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.isPreparingLink || !canSend(share))
        } else {
            Button {
                if let internalLink {
                    copyToPasteboard(internalLink)
                    flashCopied()
                }
            } label: {
                Text(showsCopied ? String(localized: "Copied") : String(localized: "Copy private link"))
            }
            .buttonStyle(.bordered)
            .disabled(internalLink == nil)
        }
    }

    private func flashCopied() {
        copiedTask?.cancel()
        showsCopied = true

        copiedTask = Task {
            try? await Task.sleep(for: .seconds(1))

            guard !Task.isCancelled else { return }

            showsCopied = false
        }
    }

    private var sendLabel: String {
        if shareeType == .anyone {
            return String(localized: "Share public link")
        }

        return String(localized: "Save share")
    }

    /// Structural sendability — gates whether the action buttons render at all.
    private func structuralCanSend(_ share: NKUnifiedShare) -> Bool {
        !share.sources.isEmpty
            && !share.recipients.isEmpty
            && share.permissions.contains { $0.enabled }
            && !share.properties.contains { $0.required && ($0.value ?? "").isEmpty }
    }

    private func canSend(_ share: NKUnifiedShare) -> Bool {
        structuralCanSend(share)
            && model.propertyErrors.isEmpty
            && model.pendingProperties.isEmpty
    }

    private func copyToPasteboard(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}

/// A simple left-to-right layout that wraps its subviews onto new rows when they overflow.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalWidth = max(totalWidth, rowWidth)
                totalHeight += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalWidth = max(totalWidth, rowWidth)
        totalHeight += rowHeight
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Carries the "Add people" field's frame up to the ZStack so the dropdown can sit beneath it.
private struct AddPeopleFieldAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private extension UnifiedShareEditView {
    enum ShareeType {
        case invited
        case anyone
    }

    enum PermissionSelection: Equatable {
        case unset
        case custom
        case preset(String)
    }

    enum EditorDeletionTarget {
        case share(id: String)
        case recipient(shareID: String, recipient: NKUnifiedShareRecipient)

        var isRecipient: Bool {
            if case .recipient = self {
                return true
            }

            return false
        }
    }
}

private struct PermissionToggleRow: View {
    let permission: NKUnifiedSharePermission
    let onChange: (Bool) -> Void

    @State private var isOn: Bool

    init(permission: NKUnifiedSharePermission, onChange: @escaping (Bool) -> Void) {
        self.permission = permission
        self.onChange = onChange
        _isOn = State(initialValue: permission.enabled)
    }

    var body: some View {
        Toggle(permission.displayName, isOn: $isOn)
            .onChange(of: isOn) {
                onChange(isOn)
            }
    }
}

/// Renders the right editor for a property's concrete type, with a hint/error caption.
private struct PropertyRow: View {
    let property: NKUnifiedShareProperty
    let error: String?
    let onCommit: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            editor

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(error != nil ? Color.red : Color.secondary)
            }
        }
    }

    private var caption: String? {
        if let error, !error.isEmpty {
            return error
        }

        if let hint = property.hint, !hint.isEmpty {
            return hint
        }

        return nil
    }

    @ViewBuilder
    private var editor: some View {
        switch property {
        case let property as NKUnifiedSharePropertyBoolean:
            BooleanPropertyEditor(property: property, onCommit: onCommit)
        case let property as NKUnifiedSharePropertyEnum:
            EnumPropertyEditor(property: property, onCommit: onCommit)
        case let property as NKUnifiedSharePropertyDate:
            DatePropertyEditor(property: property, onCommit: onCommit)
        case let property as NKUnifiedSharePropertyPassword:
            TextPropertyEditor(property: property, secure: true, onCommit: onCommit)
        case let property as NKUnifiedSharePropertyString:
            TextPropertyEditor(property: property, secure: false, onCommit: onCommit)
        default:
            LabeledContent(property.displayName) {
                Text(property.value ?? "").foregroundStyle(.secondary)
            }
        }
    }
}

private struct BooleanPropertyEditor: View {
    let property: NKUnifiedSharePropertyBoolean
    let onCommit: (String?) -> Void
    @State private var isOn: Bool

    init(property: NKUnifiedSharePropertyBoolean, onCommit: @escaping (String?) -> Void) {
        self.property = property
        self.onCommit = onCommit
        _isOn = State(initialValue: property.value == "true")
    }

    var body: some View {
        Toggle(property.displayName, isOn: $isOn)
            .onChange(of: isOn) {
                onCommit(isOn ? "true" : "false")
            }
    }
}

private struct EnumPropertyEditor: View {
    let property: NKUnifiedSharePropertyEnum
    let onCommit: (String?) -> Void
    @State private var selection: String?

    init(property: NKUnifiedSharePropertyEnum, onCommit: @escaping (String?) -> Void) {
        self.property = property
        self.onCommit = onCommit

        let value = property.value
        _selection = State(initialValue: (value?.isEmpty ?? true) ? nil : value)
    }

    var body: some View {
        Picker(property.displayName, selection: $selection) {
            ForEach(property.validValues, id: \.self) { value in
                Text(value).tag(String?.some(value))
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selection) {
            if let selection {
                onCommit(selection)
            }
        }
    }
}

private struct DatePropertyEditor: View {
    let property: NKUnifiedSharePropertyDate
    let onCommit: (String?) -> Void
    @State private var date: Date
    @State private var hasDate: Bool
    @State private var showsPicker = false

    init(property: NKUnifiedSharePropertyDate, onCommit: @escaping (String?) -> Void) {
        self.property = property
        self.onCommit = onCommit
        let parsed = Self.parse(property.value)
        _date = State(initialValue: parsed ?? Date())
        _hasDate = State(initialValue: parsed != nil)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(property.displayName)
                .foregroundStyle(.primary)

            Spacer()

            if hasDate {
                Text(date, format: Date.FormatStyle(date: .abbreviated))
                    .foregroundStyle(.secondary)

                Button {
                    hasDate = false

                    if let value = property.value, !value.isEmpty {
                        onCommit(nil)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            } else {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showsPicker = true
        }
        .popover(isPresented: $showsPicker) {
            DatePicker(
                "",
                selection: Binding(
                    get: { date },
                    set: { picked in
                        date = picked
                        hasDate = true
                        onCommit(Self.format(picked))
                    }
                ),
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(width: 320)
            .padding(8)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var dateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let lower = max(Self.parse(property.minDate) ?? today, today)
        let upper = Self.parse(property.maxDate) ?? .distantFuture

        return lower...max(lower, upper)
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = .current
        return formatter
    }()

    static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else {
            return nil
        }

        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    static func format(_ date: Date) -> String {
        formatter.string(from: Calendar.current.startOfDay(for: date))
    }
}

private struct TextPropertyEditor: View {
    let property: NKUnifiedShareProperty
    let secure: Bool
    let onCommit: (String?) -> Void
    @State private var text: String
    @State private var committed: String
    @State private var isPasswordVisible = false
    @FocusState private var focused: Bool

    init(property: NKUnifiedShareProperty, secure: Bool, onCommit: @escaping (String?) -> Void) {
        self.property = property
        self.secure = secure
        self.onCommit = onCommit
        let initial = property.value ?? ""
        _text = State(initialValue: initial)
        _committed = State(initialValue: initial)
    }

    var body: some View {
        HStack {
            field
                .focused($focused)

            if secure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? String(localized: "Hide password") : String(localized: "Show password"))
            }
        }
        .onChange(of: focused) {
            if !focused {
                commit()
            }
        }
        .onSubmit {
            commit()
        }
    }

    private var isMultiline: Bool {
        guard let maxLength = (property as? NKUnifiedSharePropertyString)?.maxLength else {
            return property is NKUnifiedSharePropertyString
        }

        return maxLength > 255
    }

    @ViewBuilder
    private var field: some View {
        if secure && !isPasswordVisible {
            SecureField(property.displayName, text: $text)
        } else if isMultiline {
            TextField(property.displayName, text: $text, axis: .vertical)
                .lineLimit(1...3)
        } else {
            TextField(property.displayName, text: $text)
        }
    }

    private func commit() {
        guard text != committed else {
            return
        }

        committed = text
        onCommit(text)
    }
}

private struct CustomLinkRow: View {
    let recipient: NKUnifiedShareRecipient
    let onCommit: (String) -> Void
    let onRegenerate: () -> Void
    private let prefix: String
    @State private var token: String
    @State private var committed: String
    @FocusState private var focused: Bool

    private static let maxTokenLength = 32

    init(recipient: NKUnifiedShareRecipient, onCommit: @escaping (String) -> Void, onRegenerate: @escaping () -> Void) {
        self.recipient = recipient
        self.onCommit = onCommit
        self.onRegenerate = onRegenerate
        let initial = recipient.secret.value ?? ""
        _token = State(initialValue: initial)
        _committed = State(initialValue: initial)

        // The prefix is the link URL with the token suffix stripped (e.g. ".../index.php/s/").
        let url = recipient.secret.url ?? ""
        if !initial.isEmpty, url.hasSuffix(initial) {
            self.prefix = String(url.dropLast(initial.count))
        } else {
            self.prefix = url
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Custom link"))

            if !prefix.isEmpty {
                Text(prefix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField(String(localized: "Link token"), text: $token)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .focused($focused)
                    .onChange(of: token) {
                        if token.count > Self.maxTokenLength {
                            token = String(token.prefix(Self.maxTokenLength))
                        }
                    }
                    .onChange(of: focused) {
                        if !focused, token != committed, !token.isEmpty {
                            committed = token
                            onCommit(token)
                        }
                    }

                Button {
                    onRegenerate()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Refresh link"))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    UnifiedShareEditView(
        model: UnifiedShareEditModel(
            account: "",
            state: .shareUpdated(share: .mock),
            recipientResults: .mocks,
            permissionPresets: [
                NKUnifiedSharePermissionPreset(class: "viewer", displayName: "Can view"),
                NKUnifiedSharePermissionPreset(class: "editor", displayName: "Can edit")
            ]
        )
    )
}
