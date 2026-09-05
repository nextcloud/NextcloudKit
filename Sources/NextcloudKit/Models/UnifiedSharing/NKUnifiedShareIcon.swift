// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Icon attached to an owner, source, recipient, or permission category.
///
/// The OpenAPI declares this as `anyOf <IconSVG, IconURL>`. The two variants have disjoint key
/// sets (`svg` vs `light`+`dark`) so a single flat struct with all keys optional decodes either
/// shape cleanly with synthesized Codable.
public struct NKUnifiedShareIcon: Codable, Sendable {
    /// Inline SVG body (IconSVG variant).
    public let svg: String?

    /// Absolute URL to a light-theme image (IconURL variant).
    public let light: String?

    /// Absolute URL to a dark-theme image (IconURL variant).
    public let dark: String?
}
