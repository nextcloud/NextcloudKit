// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension String {
    public func sanitizeForBidiCharacters(isFolder: Bool, isRTL: Bool = false) -> String {
            let ns = self as NSString
            let base = ns.deletingPathExtension
            let ext = ns.pathExtension

            guard !ext.isEmpty else { return base }

            let dangerousBidiScalars: Set<UInt32> = [
                0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
                0x200E, 0x200F, 0x2066, 0x2067, 0x2068,
                0x2069, 0x061C
            ]
            let containsBidi = base.unicodeScalars.contains { dangerousBidiScalars.contains($0.value) }

            if isRTL {
                if containsBidi {
                    return "\u{202C}\u{2066}.\(ext)\u{2069}" + base
                } else {
                    return ".\(ext)" + base
                }
            } else {
                if containsBidi {
                    return base + "\u{202C}\u{2066}.\(ext)\u{2069}"
                } else {
                    return base + "." + ext
                }
            }
        }
}
