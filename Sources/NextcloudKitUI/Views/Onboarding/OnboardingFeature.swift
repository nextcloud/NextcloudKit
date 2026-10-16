// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// A feature highlighted in an ``OnboardingView`` row.
///
public struct OnboardingFeature {
    let icon: Image
    let title: String
    let description: String?

    ///
    /// Create a new onboarding feature.
    ///
    /// - Parameters:
    ///     - icon: The image shown on the leading side of the row. Template images and SF Symbols are tinted.
    ///     - title: The bold headline of the row.
    ///     - description: Optional secondary text below the title.
    ///
    public init(icon: Image, title: String, description: String? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
    }
}
