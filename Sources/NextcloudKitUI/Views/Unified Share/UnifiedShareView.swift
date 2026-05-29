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

                    audiencePicker

                    //            VStack(spacing: 18) {
                    if shareeType == .invited {
                        TextField(
                            String(localized: "Add people"),
                            text: $recipients
                        )
                        .textFieldStyle(.roundedBorder)
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
    }

    private var audiencePicker: some View {
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
