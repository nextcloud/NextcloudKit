// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

/// View used for Unified Sharing.
public struct UnifiedShareView: View {
    let fileName: String
    let account: String
    @State private var model: UnifiedShareViewModel

    @State private var shareeType: ShareeType = .invited
    @State private var permission: Permission = .canView
    @State private var isSettingsExpanded = true
    @State private var recipients = ""
    @State private var note = ""
    @State private var addPeopleFieldHeight: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    public init(fileName: String, account: String) {
        self.fileName = fileName
        self.account = account
        model = UnifiedShareViewModel(account: account)
    }

    init(fileName: String, model: UnifiedShareViewModel) {
        self.fileName = fileName
        self.account = model.account
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            switch model.state {
                case .loading:
                    ProgressView()
                case .shareUpdated(let share):
                    Text(String(localized: "Share \(fileName)"))
                        .font(.title)
                    //                .foregroundStyle(.primary)

                    shareeTypePicker

                    //            VStack(spacing: 18) {
                    if shareeType == .invited {
                        TextField(
                            String(localized: "Add people"),
                            text: $recipients
                        )
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: recipients) {
                            model.searchRecipients(query: recipients)
                        }
                        // Measure the field so the dropdown can sit just beneath it.
                        .background {
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear { addPeopleFieldHeight = proxy.size.height }
                                    .onChange(of: proxy.size.height) { addPeopleFieldHeight = proxy.size.height }
                            }
                        }
                        // Float the suggestions just below the field, overlaying the
                        // rest of the form instead of pushing it down.
                        .overlay(alignment: .topLeading) {
                            if !model.recipientResults.isEmpty {
                                recipientDropdown
                                    .offset(y: addPeopleFieldHeight + 4)
                            }
                        }
                        .zIndex(1)
                    }

                    permissionField
                    settingsRow

                    TextField(
                        String(localized: "Note to recipients"),
                        text: $note,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)

                    actionButtons

                case .error(let error):
                    Text("Error")
            }

            //            }

        }
        .padding(.horizontal, 26)
        .padding(.top, 10)
        .onAppear {
            model.createShare()
        }
    }

    private var shareeTypePicker: some View {
        Picker("", selection: $shareeType) {
            Text(String(localized: "Invited"))
                .tag(ShareeType.invited)

            Text(String(localized: "Anyone"))
                .tag(ShareeType.anyone)
        }
        .pickerStyle(.segmented)
    }

    private var permissionField: some View {
        LabeledContent(String(localized: shareeType == .anyone ? "Anyone with the link" : "Participants")) {
            Picker(String(localized: "Participants"), selection: $permission) {
                ForEach(Permission.allCases) { permission in
                    Text(permission.localizedTitle)
                        .tag(permission)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var settingsRow: some View {
        DisclosureGroup(isExpanded: $isSettingsExpanded) {
            Text("Test")
            Text("Test")
        } label: {
            Text(String(localized: "Settings"))
        }
    }

    private var recipientDropdown: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.recipientResults, id: \.value) { recipient in
                    Button {
                        selectRecipient(recipient)
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

    private func selectRecipient(_ recipient: NKUnifiedShareRecipient) {
        recipients = ""
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(String(localized: "Copy link")) {
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button(String(localized: "Send")) {
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 18)
    }
}

private extension UnifiedShareView {
    enum ShareeType {
        case invited
        case anyone
    }

    enum Permission: CaseIterable, Identifiable {
        case canView
        case canEdit
        case fileDrop
        case customPermissions

        var id: Self {
            self
        }

        var localizedTitle: String {
            switch self {
                case .canView:
                    String(localized: "Can view")
                case .canEdit:
                    String(localized: "Can edit")
                case .fileDrop:
                    String(localized: "File drop")
                case .customPermissions:
                    String(localized: "Custom permissions")
            }
        }
    }
}

#Preview {
    UnifiedShareView(
        fileName: "Test.txt",
        model: UnifiedShareViewModel(account: "", state: .shareUpdated(share: .mock))
    )
}
