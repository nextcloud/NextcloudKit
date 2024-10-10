//
//  File.swift
//  NextcloudKit
// 
//  Created by Milen Pivchev on 09.10.24.
//  Copyright © 2024 Milen Pivchev. All rights reserved.
//
//  Author: Milen Pivchev <milen.pivchev@nextcloud.com>
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

//
//  AutoRenameManager.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 09.10.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

public class FileAutoRenamer {
    public static let shared: FileAutoRenamer = {
        let instance = FileAutoRenamer()
        return instance
    }()
//
//    public private(set) var forbiddenFileNames: [String] = [] {
//        didSet {
//            forbiddenFileNames = forbiddenFileNames.map({$0.uppercased()})
//        }
//    }
//
//    public private(set) var forbiddenFileNameBasenames: [String] = [] {
//        didSet {
//            forbiddenFileNameBasenames = forbiddenFileNameBasenames.map({$0.uppercased()})
//        }
//    }

    public private(set) var forbiddenFileNameCharacters: [String] = []

    public private(set) var forbiddenFileNameExtensions: [String] = [] {
        didSet {
            forbiddenFileNameExtensions = forbiddenFileNameExtensions.map({$0.uppercased()})
        }
    }

    private let REPLACEMENT = "_"

    public func setup(forbiddenFileNameCharacters: [String], forbiddenFileNameExtensions: [String]) {
        self.forbiddenFileNameCharacters = forbiddenFileNameCharacters
        self.forbiddenFileNameExtensions = forbiddenFileNameExtensions
    }

    func rename(filename: String, isFolderPath: Bool = false) -> String {
//        let capabilities = NCCapabilities.shared.getCapabilities(account: account)

        var pathSegments = filename.split(separator: OCFile.PATH_SEPARATOR).map { String($0) }

            if isFolderPath {
                forbiddenFileNameCharacters.removeAll { $0 == String(OCFile.PATH_SEPARATOR) }
            }

            pathSegments = pathSegments.map { segment in
                var modifiedSegment = segment
                forbiddenFileNameCharacters.forEach { forbiddenChar in
                    if modifiedSegment.contains(forbiddenChar) {
                        modifiedSegment = modifiedSegment.replacingOccurrences(of: forbiddenChar, with: REPLACEMENT)
                    }
                }
                return modifiedSegment
            }

            pathSegments = pathSegments.map { segment in
                var modifiedSegment = segment
                forbiddenFileNameExtensions.forEach { forbiddenExtension in
                    if forbiddenExtension == StringConstants.SPACE {
                        modifiedSegment = modifiedSegment.trimmingCharacters(in: .whitespaces)
                    }

                    if modifiedSegment.hasSuffix(forbiddenExtension) || modifiedSegment.hasPrefix(forbiddenExtension) {
                        modifiedSegment = modifiedSegment.replacingOccurrences(of: forbiddenExtension, with: REPLACEMENT)
                    }
                }
                return modifiedSegment
            }

        let result = pathSegments.joined(separator: String(OCFile.PATH_SEPARATOR))
//        return capability.shouldRemoveNonPrintableUnicodeCharactersAndConvertToUTF8() ? removeNonPrintableUnicodeCharacters(convertToUTF8(result)) : result

        return removeNonPrintableUnicodeCharacters(convertToUTF8(result))
    }

    private func convertToUTF8(_ filename: String) -> String {
        return String(data: filename.data(using: .utf8) ?? Data(), encoding: .utf8) ?? filename
    }

    private func removeNonPrintableUnicodeCharacters(_ filename: String) -> String {
        let regex = try! NSRegularExpression(pattern: "\\p{C}", options: [])
        let range = NSRange(location: 0, length: filename.utf16.count)
        return regex.stringByReplacingMatches(in: filename, options: [], range: range, withTemplate: "")
    }
}

// Support structs and classes for compatibility (mock-up)

struct StringConstants {
    static let SPACE = " "
}

class OCFile {
    static let PATH_SEPARATOR: Character = "/"
}

struct NextcloudVersion {
    static let nextcloud_30 = NextcloudVersion(version: "30")

    let version: String

    func isNewerOrEqual(to otherVersion: NextcloudVersion) -> Bool {
        return version >= otherVersion.version
    }
}

class OCCapability {
    var version: NextcloudVersion
    var forbiddenFilenameCharactersJson: String?
    var forbiddenFilenameExtensionJson: String?

    init(version: NextcloudVersion, forbiddenFilenameCharactersJson: String?, forbiddenFilenameExtensionJson: String?) {
        self.version = version
        self.forbiddenFilenameCharactersJson = forbiddenFilenameCharactersJson
        self.forbiddenFilenameExtensionJson = forbiddenFilenameExtensionJson
    }

    func forbiddenFilenameCharacters() -> [String] {
        return ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"] // Example characters
    }

    func forbiddenFilenameExtensions() -> [String] {
        return [".", " "]
    }

    func shouldRemoveNonPrintableUnicodeCharactersAndConvertToUTF8() -> Bool {
        return true
    }
}
