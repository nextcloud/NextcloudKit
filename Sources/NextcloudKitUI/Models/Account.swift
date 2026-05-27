// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Data model for locally configured accounts.
///
public struct Account: Identifiable, Sendable, Equatable {
    ///
    /// Unique identifier for a model instance during its lifetime in memory.
    ///
    /// This is required by `Identifiable` for iteration and identification in SwiftUI collections.
    ///
    public let id: String

    ///
    /// The image to present for this account.
    ///
    public let image: Image

    ///
    /// The host address of this account.
    ///
    public let host: URL

    ///
    /// The display name of this account. Not to confuse with the user name used to login with.
    ///
    public let name: String

    ///
    /// Create a new instance.
    ///
    /// - Parameters:
    ///     - name: See ``name``.
    ///     - host: See ``host``.
    ///     - image: See ``image``.
    ///
    public init(_ name: String, on host: URL, with image: Image) {
        self.id = "\(name)@\(host)"
        self.name = name
        self.host = host
        self.image = image
    }

    public static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.id == rhs.id
    }
}
