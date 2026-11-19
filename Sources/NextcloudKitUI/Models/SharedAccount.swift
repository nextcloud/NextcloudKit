// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Data model for accounts from other apps to be offered to a user during the login flow.
///
public struct SharedAccount: Identifiable, Sendable {
    ///
    /// Unique identifier for a model instance during its lifetime in memory.
    ///
    /// This is required by `Identifiable` for iteration and identification in SwiftUI collections.
    ///
    public let id: UUID

    ///
    /// The image to present for this shared account.
    ///
    public let image: Image

    ///
    /// The host address of this shared account.
    ///
    public let host: URL

    ///
    /// The name to display for this shared account.
    ///
    public let name: String

    ///
    /// The login name of this shared account, shown next to ``name`` when set.
    ///
    public let user: String?

    ///
    /// Create a new instance.
    ///
    /// - Parameters:
    ///     - name: See ``name``.
    ///     - user: See ``user``.
    ///     - host: See ``host``.
    ///     - image: See ``image``.
    ///
    public init(_ name: String, user: String? = nil, on host: URL, with image: Image) {
        self.id = UUID()
        self.name = name
        self.user = user
        self.host = host
        self.image = image
    }
}
