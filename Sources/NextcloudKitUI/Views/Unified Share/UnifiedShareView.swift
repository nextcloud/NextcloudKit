// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// View used for Unified Sharing.
public struct UnifiedShareView: View {
    @State private var selectedAudience: ShareeType = .invited
    @State private var permission: Permission = .canView
    @State private var isSettingsExpanded = true
    @State private var recipients = ""
    @State private var note = ""

    public init() { }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 24) {
                    Text(String(localized: "Share Abc.txt"))
                        .font(.system(size: 48 / 2, weight: .medium))
                        .foregroundStyle(.primary)

                    audiencePicker

                    VStack(spacing: 18) {
                        TextField(
                            String(localized: "Add people"),
                            text: $recipients
                        )
                        .textFieldStyle(.roundedBorder)

                        permissionField
                        settingsRow

                        TextField(
                            String(localized: "Note to recipients"),
                            text: $note,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    actionButtons
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 26)
            }
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.background.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.separator.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    private var audiencePicker: some View {
        Picker(String(localized: ""), selection: $selectedAudience) {
            Label(
                String(localized: "Invited"),
                systemImage: "checkmark"
            )
            .tag(ShareeType.invited)

            Text(String(localized: "Anyone"))
                .tag(ShareeType.anyone)
        }
        .pickerStyle(.segmented)
    }

    private var permissionField: some View {
        LabeledContent(String(localized: "Participants")) {
            Picker(String(localized: "Participants"), selection: $permission) {
                ForEach(Permission.allCases) { permission in
                    Text(permission.localizedTitle)
                        .tag(permission)
                }
            }
            .labelsHidden()
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
    UnifiedShareView()
}
