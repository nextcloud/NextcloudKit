// SPDX-FileCopyrightText: 2020 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

//
//  AutoRenameManager.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 09.10.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

public class FileAutoRenamer {
    public static let shared: FileAutoRenamer = {
        let instance = FileAutoRenamer()
        return instance
    }()

    private var forbiddenFileNameCharacters: [String] = []

    private var forbiddenFileNameExtensions: [String] = [] {
        didSet {
            forbiddenFileNameExtensions = forbiddenFileNameExtensions.map({$0.lowercased()})
        }
    }

    private let replacement = "_"

    public func setup(forbiddenFileNameCharacters: [String], forbiddenFileNameExtensions: [String]) {
        self.forbiddenFileNameCharacters = forbiddenFileNameCharacters
        self.forbiddenFileNameExtensions = forbiddenFileNameExtensions
    }

    public func rename(filename: String, isFolderPath: Bool = false) -> String {
        var pathSegments = filename.split(separator: "/", omittingEmptySubsequences: false).map { String($0) }

        if isFolderPath {
            forbiddenFileNameCharacters.removeAll { $0 == "/" }
        }

        pathSegments = pathSegments.map { segment in
            var modifiedSegment = segment

            forbiddenFileNameCharacters.forEach { forbiddenChar in
                if modifiedSegment.contains(forbiddenChar) {
                    modifiedSegment = modifiedSegment.replacingOccurrences(of: forbiddenChar, with: replacement, options: .caseInsensitive)
                }
            }

            if forbiddenFileNameExtensions.contains(" ") {
                modifiedSegment = modifiedSegment.trimmingCharacters(in: .whitespaces)
            }

            // Replace forbidden extension, if any (ex. .part -> _part)
            forbiddenFileNameExtensions.forEach { forbiddenExtension in
                if modifiedSegment.lowercased().hasSuffix(forbiddenExtension) && isFullExtension(forbiddenExtension) {
                    let changedExtension = forbiddenExtension.replacingOccurrences(of: ".", with: replacement, options: .caseInsensitive)
                    modifiedSegment = modifiedSegment.replacingOccurrences(of: forbiddenExtension, with: changedExtension, options: .caseInsensitive)
                }
            }

            // Keep original allowed extension and add it at the end (ex file.test.txt becomes file.test)
            let fileExtension = modifiedSegment.fileExtension
            modifiedSegment = modifiedSegment.withRemovedFileExtension

            // Replace other forbidden extensions. Original allowed extension is ignored.
            forbiddenFileNameExtensions.forEach { forbiddenExtension in
                if modifiedSegment.uppercased().hasSuffix(forbiddenExtension) || modifiedSegment.uppercased().hasPrefix(forbiddenExtension) {
                    modifiedSegment = modifiedSegment.replacingOccurrences(of: forbiddenExtension, with: replacement, options: .caseInsensitive)
                }
            }

            // If there is an original allowed extension, add it back (ex file_test becomes file_test.txt)
            if !fileExtension.isEmpty {
                modifiedSegment.append(".\(fileExtension.lowercased())")
            }

            return modifiedSegment
        }

        let result = pathSegments.joined(separator: "/")
        return removeNonPrintableUnicodeCharacters(convertToUTF8(result))
    }

    private func convertToUTF8(_ filename: String) -> String {
        return String(data: filename.data(using: .utf8) ?? Data(), encoding: .utf8) ?? filename
    }

    private func isFullExtension(_ string: String) -> Bool {
        let pattern = "\\.[a-zA-Z0-9]+$"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.firstMatch(in: string, options: [], range: range) != nil
    }

    private func removeNonPrintableUnicodeCharacters(_ filename: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: "\\p{C}", options: [])
            let range = NSRange(location: 0, length: filename.utf16.count)
            return regex.stringByReplacingMatches(in: filename, options: [], range: range, withTemplate: "")
        } catch {
            print("Could not remove printable unicode characters.")
            return filename
        }
    }
}
