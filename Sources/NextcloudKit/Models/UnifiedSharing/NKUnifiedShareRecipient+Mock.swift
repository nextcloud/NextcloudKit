// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import Foundation

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
            initiator: nil
        )
    }
}

public extension Array where Element == NKUnifiedShareRecipient {
    /// Sample recipients, e.g. for autocomplete results and list previews.
    static var mocks: [NKUnifiedShareRecipient] {
        [
            NKUnifiedShareRecipient(class: "user", value: "bob", instance: nil, displayName: "Bob", icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil), secret: .init(updatable: false), initiator: nil),
            NKUnifiedShareRecipient(class: "group", value: "team", instance: nil, displayName: "Team", icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil), secret: .init(updatable: false), initiator: nil),
            NKUnifiedShareRecipient(class: "federated_user", value: "carol@example.com", instance: "example.com", displayName: "Carol (example.com)", icon: nil, secret: .init(updatable: false), initiator: nil),
            NKUnifiedShareRecipient(class: "user", value: "dave", instance: nil, displayName: "Dave", icon: nil, secret: .init(updatable: false), initiator: nil)
        ]
    }
}
#endif
