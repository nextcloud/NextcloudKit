// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

extension Image {
    ///
    /// The app's own icon, loaded from the largest icon file the build lists in the Info.plist.
    ///
    public static var appIcon: Image? {
        #if canImport(UIKit)
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primaryIcon = icons?["CFBundlePrimaryIcon"] as? [String: Any]

        guard let name = (primaryIcon?["CFBundleIconFiles"] as? [String])?.last, let image = UIImage(named: name) else { return nil }

        return Image(uiImage: image)
        #else
        return nil
        #endif
    }
}
