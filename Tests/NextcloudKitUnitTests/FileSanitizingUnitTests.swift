// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import Foundation
@testable import NextcloudKit

@Suite(.serialized) struct FileSanitizingUnitTests {
    // MARK: - Helper for test expectation
    func expectedSanitized(for filename: String, isFolder: Bool, isRTL: Bool) -> String {
        let ns = filename as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension

        if isFolder || ext.isEmpty { return base }

        let dangerousBidiScalars: Set<UInt32> = [
            0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
            0x200E, 0x200F, 0x2066, 0x2067, 0x2068,
            0x2069, 0x061C
        ]
        let containsBidi = base.unicodeScalars.contains { dangerousBidiScalars.contains($0.value) }

        if isRTL {
            return containsBidi
                ? "\u{202C}\u{2066}.\(ext)\u{2069}" + base
                : ".\(ext)" + base
        } else {
            return containsBidi
                ? base + "\u{202C}\u{2066}.\(ext)\u{2069}"
                : base + "." + ext
        }
    }

    // MARK: - Test Cases
    @Test
    func testSanitizeForBidiCharacters_UIRendering() {
        let cases: [(String, Bool, Bool)] = [
            // LTR, normal and malicious
            ("invoice\u{202E}cod.exe", false, false),   // malicious RLO
            ("archive.tar.gz", false, false),           // multiple dots
            ("myFolder", true, false),                  // folder
            ("document.txt", false, false),             // normal file
            ("Foo\u{202E}dm.exe", false, false),        // another malicious

            // RTL Hebrew / Arabic safe
            ("תמונה.jpg", false, true),                 // Hebrew base
            ("מכתב.pdf", false, true),                 // Hebrew base
            ("שלום", true, true),                       // Hebrew folder
            ("مرحبا", true, true),                      // Arabic folder
            ("ملف.pdf", false, true),                   // Arabic file

            // Mixed-language
            ("report.ملف", false, true),                // English base, Arabic extension
            ("وثيقة.docx", false, true),                // Arabic base, English extension
            ("summary.תמונה", false, true),            // English base, Hebrew extension
            ("מסמך.txt", false, true),                  // Hebrew base, English extension

            // Mixed-language with malicious bidi
            ("report\u{202E}cod.exe", false, true),     // English base + RLO trick
            ("ملف\u{202E}cod.exe", false, true),       // Arabic base + RLO trick
            ("תמונה\u{202E}cod.exe", false, true)      // Hebrew base + RLO trick
        ]

        for (filename, isFolder, isRTL) in cases {
            let result = filename.sanitizeForBidiCharacters(isFolder: isFolder, isRTL: isRTL)
            let expected = expectedSanitized(for: filename, isFolder: isFolder, isRTL: isRTL)
            #expect(result == expected, "Failed for filename: \(filename), isFolder: \(isFolder), isRTL: \(isRTL)")
        }
    }
}

