// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit
#if canImport(UIKit)
import UIKit
#endif

/// View used for Unified Sharing.
public struct UnifiedShareEditView: View {
    let fileName: String
    let account: String
    @State private var model: UnifiedShareEditModel

    @State private var shareeType: ShareeType = .invited
    @State private var permissionSelection: PermissionSelection = .unset
    @State private var isSettingsExpanded = true
    @State private var recipients = ""
    @State private var note = ""
    @Environment(\.colorScheme) private var colorScheme

    public init(fileName: String, account: String) {
        self.fileName = fileName
        self.account = account
        model = UnifiedShareEditModel(account: account)
    }

    init(fileName: String, model: UnifiedShareEditModel) {
        self.fileName = fileName
        self.account = model.account
        self.model = model
    }

    public var body: some View {
        ZStack {
            switch model.state {
                case .loading:
                    ProgressView()
                case .shareUpdated(let share):

                    Form {
//                        VStack(alignment: .leading, spacing: 24) {
                        Section {
                            Text(String(localized: "Share \(fileName)"))
                                .font(.title)
                            //                .foregroundStyle(.primary)

                        }

                        Section {
                            shareeTypePicker

                            //            VStack(spacing: 18) {
                            if shareeType == .invited {
                                if !share.recipients.isEmpty {
                                    recipientPills(share: share)
                                }

                                TextField(
                                    String(localized: "Add people"),
                                    text: $recipients
                                )
                                .onChange(of: recipients) {
                                    model.searchRecipients(query: recipients)
                                }
                                // Publish the field's frame so the dropdown can be drawn outside the Form.
                                .anchorPreference(key: AddPeopleFieldAnchorKey.self, value: .bounds) { $0 }
                            } else {
                                recipientPills(share: share)
                            }

                            permissionField(share: share)

                            ForEach(basicProperties(share), id: \.class) { property in
                                propertyRow(property)
                            }
                        }
                        settingsRow(share: share)

                        TextField(
                            String(localized: "Note to recipients"),
                            text: $note,
                            axis: .vertical
                        )

                        actionButtons(share: share)
//                        }

                    }
////                    .padding(.horizontal, 26)
//                    .padding(.top, 10)
                    .onDisappear {
                        model.deleteShare(share: share)
                    }
                    .navigationTitle("Share")
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

                case .error(let error):
                    Text(error.localizedDescription)
            }
            
            //            }
            
            
        }
        .task {
            model.createShare()
            model.loadCapabilities()
        }

        Spacer()
}

    private var shareeTypePicker: some View {
        Picker("", selection: $shareeType) {
            Text(String(localized: "Invited People"))
                .tag(ShareeType.invited)

            Text(String(localized: "Anyone"))
                .tag(ShareeType.anyone)
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)

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

        if isCustomSelected(share) {
            ForEach(share.permissions, id: \.class) { permission in
                PermissionToggleRow(permission: permission) { enabled in
                    model.setPermission(share: share, permissionClass: permission.class, enabled: enabled)
                }
            }
        }
    }

    /// Sentinel tag for the synthesized "Custom" option (distinct from any real preset class).
    private static let customTag = "__nk_custom_permissions__"

    /// Presets from the capability, narrowed to those the share's permissions reference.
    private func applicablePresets(_ share: NKUnifiedShare) -> [NKUnifiedSharePermissionPreset] {
        let applicable = Set(share.permissions.flatMap { $0.presets })
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

    /// Advanced properties live behind the disclosure; basic ones are shown inline in the form.
    private func settingsRow(share: NKUnifiedShare) -> some View {
        DisclosureGroup(isExpanded: $isSettingsExpanded) {
            ForEach(advancedProperties(share), id: \.class) { property in
                propertyRow(property)
            }
        } label: {
            Text(String(localized: "Settings"))
        }
    }

    private func basicProperties(_ share: NKUnifiedShare) -> [NKUnifiedShareProperty] {
        share.properties.filter { !$0.advanced }
    }

    private func advancedProperties(_ share: NKUnifiedShare) -> [NKUnifiedShareProperty] {
        share.properties.filter { $0.advanced }
    }

    private func propertyRow(_ property: NKUnifiedShareProperty) -> some View {
        LabeledContent(property.displayName) {
            Text(property.value ?? property.hint ?? "")
                .foregroundStyle(.secondary)
        }
    }

    private func recipientDropdown(share: NKUnifiedShare) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.recipientResults, id: \.value) { recipient in
                    Button {
                        model.addRecipient(share: share, recipient: recipient)
                        recipients = ""
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

                    if recipient.value != model.recipientResults.last?.value {
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

    /// Renders the icon's URL variant (color-scheme aware). Inline SVG isn't natively renderable.
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
            ForEach(share.recipients, id: \.value) { recipient in
                recipientPill(recipient, share: share)
            }
        }
    }

    private func recipientPill(_ recipient: NKUnifiedShareRecipient, share: NKUnifiedShare) -> some View {
        HStack(spacing: 6) {
            recipientAvatar(recipient)

            Text(recipient.displayName)
                .lineLimit(1)

            Button {
                model.removeRecipient(share: share, recipient: recipient)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.quaternary))
        .overlay(Capsule().stroke(.tertiary, lineWidth: 0.5))
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
            Button(String(localized: "Copy link")) {
                copyLink(share)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .disabled(linkURL(share) == nil)

            Button(String(localized: "Send")) {
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 18)
    }

    /// The share's public link, taken from the first recipient that carries one.
    private func linkURL(_ share: NKUnifiedShare) -> String? {
        share.recipients.compactMap { $0.secret.url }.first
    }

    private func copyLink(_ share: NKUnifiedShare) {
        guard let link = linkURL(share) else {
            return
        }

        #if canImport(UIKit)
        UIPasteboard.general.string = link
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

    /// The participants dropdown state: follow the share's server preset, a chosen preset, or Custom.
    enum PermissionSelection: Equatable {
        case unset
        case custom
        case preset(String)
    }
}

/// A single permission toggle. Keeps local state for immediate feedback, then reports the change.
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

#Preview {
    UnifiedShareEditView(
        fileName: "Test.txt",
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
