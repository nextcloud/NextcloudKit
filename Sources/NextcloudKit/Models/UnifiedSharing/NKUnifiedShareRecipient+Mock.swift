// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import Foundation

private var previewPermissions: [NKUnifiedSharePermission] {
    [
        NKUnifiedSharePermission(class: "read", sourceClass: nil, displayName: "View files", hint: nil, priority: 1, presets: ["viewer", "editor"], enabled: true),
        NKUnifiedSharePermission(class: "update", sourceClass: nil, displayName: "Edit files", hint: nil, priority: 2, presets: ["editor"], enabled: false),
        NKUnifiedSharePermission(class: "share", sourceClass: nil, displayName: "Share with others", hint: nil, priority: 3, presets: ["editor"], enabled: false),
        NKUnifiedSharePermission(class: "download", sourceClass: nil, displayName: "Download files", hint: nil, priority: 4, presets: ["viewer", "editor"], enabled: true)
    ]
}

public extension NKUnifiedShareRecipient {
    /// Sample recipient for SwiftUI previews and tests.
    static var mock: NKUnifiedShareRecipient {
        NKUnifiedShareRecipient(
            class: "user",
            value: "bob",
            instance: nil,
            displayName: "Bob",
            icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil),
            secret: Secret(updatable: false),
            initiator: nil,
            permissions: previewPermissions
        )
    }
}

public extension Array where Element == NKUnifiedShareRecipient {
    /// Sample recipients, e.g. for autocomplete results and list previews.
    static var mocks: [NKUnifiedShareRecipient] {
        [
            NKUnifiedShareRecipient(class: "user", value: "bob", instance: nil, displayName: "Bob", icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil), secret: .init(updatable: false), initiator: nil, permissions: previewPermissions),
            NKUnifiedShareRecipient(class: "group", value: "team", instance: nil, displayName: "Team", icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil), secret: .init(updatable: false), initiator: nil, permissions: previewPermissions),
            NKUnifiedShareRecipient(class: "federated_user", value: "carol@example.com", instance: "example.com", displayName: "Carol (example.com)", icon: nil, secret: .init(updatable: false), initiator: nil, permissions: previewPermissions),
            NKUnifiedShareRecipient(class: "user", value: "dave", instance: nil, displayName: "Dave", icon: nil, secret: .init(updatable: false), initiator: nil, permissions: previewPermissions)
        ]
    }
}
#endif
