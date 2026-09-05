// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct PermissionToggleRow: View {
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

struct CustomLinkRow: View {
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
