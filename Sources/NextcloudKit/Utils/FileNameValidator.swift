//
//  FileNameValidator.swift
//
//
//  Created by Milen Pivchev on 12.07.24.
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

struct FileNameValidator {
    static let reservedWindowsChars = try! NSRegularExpression(pattern: "[<>:\"/\\\\|?*]", options: [])
    static let reservedUnixChars = try! NSRegularExpression(pattern: "[/<>|:&]", options: [])
    static let reservedWindowsNames = [
        "CON", "PRN", "AUX", "NUL",
        "COM0", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "COM¹", "COM²", "COM³",
        "LPT0", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
        "LPT¹", "LPT²", "LPT³"
    ]

    public static let emptyFilenameError = NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("_filename_empty_", value: "File name is empty", comment: ""))
    public static let fileAlreadyExistsError = NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("_file_already_exists_", value: "Unable to complete the operation, a file with the same name exists", comment: ""))
    public static let fileEndsWithSpacePeriodError = NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("_file_name_validator_error_ends_with_space_period_", value: "File name ends with a space or a period", comment: ""))
    public static let fileReservedNameError = NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("_file_name_validator_error_reserved_names_", value: "%s is a reserved name", comment: ""))
    public static let fileInvalidCharacterError = NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("_file_name_validator_error_invalid_character_", value: "File name contains invalid characters: %s", comment: ""))

    static func checkFileName(_ filename: String, capability: OCCapability, existedFileNames: Set<String>? = nil) -> NKError? {
        if filename.isEmpty {
            return emptyFilenameError
        }

        if isFileNameAlreadyExist(filename, fileNames: existedFileNames ?? Set()) {
            return fileAlreadyExistsError
        }

        if filename.hasSuffix(" ") || filename.hasSuffix(".") {
            return fileEndsWithSpacePeriodError
        }

        if let invalidCharacterError = checkInvalidCharacters(name: filename, capability: capability) {
            return invalidCharacterError
        }

        if capability.forbiddenFilenames,
           reservedWindowsNames.contains(filename.uppercased()) || reservedWindowsNames.contains(filename.removeFileExtension().uppercased()) {
//            return String(format: NSLocalizedString("file_name_validator_error_reserved_names", comment: ""), filename.split(separator: ".").first ?? "")
            return fileReservedNameError
        }

        if capability.forbiddenFilenameExtension {
            // TODO add logic
        }

        return nil
    }

    static func checkFolderAndFilePaths(folderPath: String, filePaths: [String], capability: OCCapability) -> Bool {
        return checkFolderPath(folderPath: folderPath, capability: capability) &&
        checkFilePaths(filePaths: filePaths, capability: capability)
    }

    static func checkFilePaths(filePaths: [String], capability: OCCapability) -> Bool {
        return filePaths.allSatisfy { checkFileName($0, capability: capability) == nil }
    }

    static func checkFolderPath(folderPath: String, capability: OCCapability) -> Bool {
        return folderPath.split { $0 == "/" || $0 == "\\" }
            .allSatisfy { checkFileName(String($0), capability: capability) == nil }
    }

    private static func checkInvalidCharacters(name: String, capability: OCCapability) -> NKError? {
        if !capability.forbiddenFilenameCharacters { return nil }

//        if let invalidCharacter = name.first(where: { String($0).range(of: reservedWindowsChars, options: .regularExpression) != nil || String($0).range(of: reservedUnixChars, options: .regularExpression) != nil }) {
////            return String(format: NSLocalizedString("file_name_validator_error_invalid_character", comment: ""), String(invalidCharacter))
//            return fileInvalidCharacterError
//        }

        for char in name {
                let charAsString = String(char)
                let range = NSRange(location: 0, length: charAsString.utf16.count)

                if reservedWindowsChars.firstMatch(in: charAsString, options: [], range: range) != nil ||
                   reservedUnixChars.firstMatch(in: charAsString, options: [], range: range) != nil {
                    return fileInvalidCharacterError
                }
            }
            return nil
    }

    static func isFileHidden(name: String) -> Bool {
        return !name.isEmpty && name.first == "."
    }

    static func isFileNameAlreadyExist(_ name: String, fileNames: Set<String>) -> Bool {
        return fileNames.contains(name)
    }
}

extension String {
    func toRegex() -> NSRegularExpression {
        return try! NSRegularExpression(pattern: self, options: [])
    }

    func removeFileExtension() -> String {
        return NSString(string: self).deletingPathExtension
    }
}

class OCCapability {
    var forbiddenFilenames: Bool = false
    var forbiddenFilenameCharacters: Bool = false
    var forbiddenFilenameExtension: Bool = false
}

class Context {
    func getString(_ key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }
}

