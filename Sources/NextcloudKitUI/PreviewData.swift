// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

// swiftlint:disable force_unwrapping

#if DEBUG

import SwiftUI

///
/// Static data available only in debug configuration for SwiftUI previews to reduce redundant code.
///
enum PreviewData {
    ///
    /// First item in ``accounts``.
    ///
    static var account: Account {
        accounts.first!
    }

    ///
    /// An array of multiple account items.
    ///
    static let accounts: [Account] = [
        Account("Jane Doe", on: URL(string: "http://localhost:8080")!, with: Image(systemName: "bird.circle.fill")),
        Account("Ariana Dane", on: URL(string: "http://localhost:33306")!, with: Image(systemName: "leaf.circle.fill")),
        Account("Jean Derp", on: URL(string: "http://localhost:1414")!, with: Image(systemName: "person.circle.fill"))
    ]

    ///
    /// An array of multiple shared accounts.
    ///
    static let sharedAccounts: [SharedAccount] = [
        SharedAccount("jane", on: URL(string: "http://localhost:8080")!, with: Image(systemName: "person.circle.fill")),
        SharedAccount("john", on: URL(string: "http://localhost:8081")!, with: Image(systemName: "bird.circle.fill")),
        SharedAccount("jean", on: URL(string: "http://localhost:8082")!, with: Image(systemName: "leaf.circle.fill"))
    ]
}

#endif
