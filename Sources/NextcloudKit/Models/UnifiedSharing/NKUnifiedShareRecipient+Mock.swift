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
            icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil)
        )
    }
}

public extension Array where Element == NKUnifiedShareRecipient {
    /// A few sample recipients, e.g. for autocomplete results.
    static var mocks: [NKUnifiedShareRecipient] {
        [
            NKUnifiedShareRecipient(class: "", value: "bob", instance: nil, displayName: "Bob", icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil)),
            NKUnifiedShareRecipient(class: "", value: "team", instance: nil, displayName: "Team", icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil)),
            NKUnifiedShareRecipient(class: "", value: "carol@example.com", instance: "example.com", displayName: "Carol (example.com)", icon: nil)
        ]
    }
}
#endif
