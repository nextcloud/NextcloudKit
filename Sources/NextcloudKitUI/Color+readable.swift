// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

extension Color {

    ///
    /// Computes a color which is expected to be readable when being rendered on a background colored in `self`.
    ///
    /// Uses the WCAG luminance formula to determine brightness.
    ///
    var readable: Color {
        // Gamma correction
        func adjust(_ channel: CGFloat) -> CGFloat {
            if channel <= 0.03928 {
                return channel / 12.92
            } else {
                return pow((channel + 0.055) / 1.055, 2.4)
            }
        }

        #if os(iOS)
        let uiColor = UIColor(self)

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .primary
        }
        #endif

        #if os(macOS)
        guard let rgbColor = NSColor(self).usingColorSpace(.sRGB) else {
            return .primary
        }

        let red = rgbColor.redComponent
        let green = rgbColor.greenComponent
        let blue = rgbColor.blueComponent
        #endif

        let luminance = 0.2126 * adjust(red) + 0.7152 * adjust(green) + 0.0722 * adjust(blue)

        if luminance < 0.5 {
            return .white
        } else {
            return .black
        }
    }
}
