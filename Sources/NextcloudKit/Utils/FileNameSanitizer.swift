//
//  File.swift
//  NextcloudKit
//
//  Created by Milen Pivchev on 09.09.25.
//

import Foundation

extension String {

    func containsBidiControlCharacters() -> Bool {
//        guard let filename = filename else { return false }

        // Decode percent-encoded string
        let decoded: String
        if let decodedStr = removingPercentEncoding {
            decoded = decodedStr
        } else {
            return false
        }

        // List of bidi control characters
        let bidiControlCharacters: [UInt32] = [
            0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
            0x200E, 0x200F, 0x2066, 0x2067, 0x2068,
            0x2069, 0x061C
        ]

        // Check each Unicode scalar
        for scalar in decoded.unicodeScalars {
            if bidiControlCharacters.contains(scalar.value) {
                return true
            }
            if scalar.value < 32 {
                return true
            }
        }

        return false
    }

    // Minimal sanitizer: remove only spoof-prone embedding/override marks and ASCII controls < U+0020.
    // Keeps helper marks (LRM/RLM/ALM/isolate) intact to avoid breaking RTL readability.
    fileprivate func removingSpoofProneBidiAndLowControls() -> String {
        let alwaysRemove: Set<UInt32> = [
            0x202A, // LRE
            0x202B, // RLE
            0x202C, // PDF
            0x202D, // LRO
            0x202E  // RLO
        ]
        let filtered = unicodeScalars.lazy.filter { s in
            let v = s.value
            if v < 0x20 { return false }           // drop ASCII controls
            if alwaysRemove.contains(v) { return false } // drop spoof-prone
            return true
        }
        return String(String.UnicodeScalarView(filtered))
    }
//
//    // If you still want a simple sanitize that preserves extension/base order:
//    public func sanitizeForBidiCharacters(isFolder: Bool, isRTL: Bool = false) -> String {
//        let ns = self as NSString
//        let base = ns.deletingPathExtension
//        let ext = ns.pathExtension
//        let dot = isFolder ? "" : "."
//        let isolatedExt = "\u{202C}\u{2066}\(dot)\(ext)\u{2069}"
//        return containsBidiControlCharacters(self) ? base + isolatedExt : base + "." + ext
//    }

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
    // Your existing splitter
    func getFilenameAndExtension(isFolder: Bool, isRTL: Bool) -> (String, String) {
        if isFolder {
            return (self, "")
        }
        let ns = self as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        let extWithDot = ext.isEmpty ? "" : "." + ext
        return isRTL ? (extWithDot, base) : (base, extWithDot)
    }
}
