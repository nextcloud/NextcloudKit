// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import Foundation

public extension NKUnifiedShare {
    /// Sample share for SwiftUI previews and tests, covering all property variants.
    static var mock: NKUnifiedShare {
        NKUnifiedShare(
            id: "preview-1",
            owner: NKUnifiedShareOwner(
                userId: "alice",
                instance: nil,
                displayName: "Alice",
                icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil)
            ),
            lastUpdated: 1_730_000_000_000,
            state: .draft,
            sources: [
                NKUnifiedShareSource(
                    class: "file",
                    value: "/Test.txt",
                    displayName: "Test.txt",
                    icon: NKUnifiedShareIcon(svg: nil, light: "https://example.com/light.png", dark: "https://example.com/dark.png")
                )
            ],
            recipients: [
//                NKUnifiedShareRecipient(
//                    class: "user",
//                    value: "bob",
//                    instance: nil,
//                    displayName: "Bob",
//                    icon: NKUnifiedShareIcon(svg: "<svg/>", light: nil, dark: nil)
//                )
            ],
            properties: [
                NKUnifiedSharePropertyDate(
                    class: "expiration",
                    displayName: "Expiration",
                    priority: 10,
                    required: false,
                    minDate: "2026-01-01"
                ),
                NKUnifiedSharePropertyEnum(
                    class: "role",
                    displayName: "Role",
                    priority: 20,
                    required: true,
                    value: "editor",
                    validValues: ["viewer", "editor"]
                ),
                NKUnifiedSharePropertyBoolean(
                    class: "download",
                    displayName: "Allow download",
                    priority: 30,
                    required: false,
                    value: "true"
                ),
                NKUnifiedSharePropertyPassword(
                    class: "password",
                    displayName: "Password",
                    hint: "Min 8 chars",
                    priority: 40,
                    required: false
                ),
                NKUnifiedSharePropertyString(
                    class: "note",
                    displayName: "Note",
                    priority: 50,
                    required: false,
                    value: "hi",
                    minLength: 0,
                    maxLength: 1000
                )
            ],
            permissions: [
                NKUnifiedSharePermission(
                    class: "download",
                    displayName: "Allow download",
                    hint: nil,
                    category: nil,
                    enabled: true
                )
            ]
        )
    }
}
#endif
