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

public class FileNameValidator {
    public static let shared: FileNameValidator = {
        let instance = FileNameValidator()
        return instance
    }()

    public var forbiddenFileNames: [String] = [] {
        didSet {
            forbiddenFileNames = forbiddenFileNames.map({$0.uppercased()})
        }
    }
    public var forbiddenFileNameBasenames: [String] = [] {
        didSet {
            forbiddenFileNameBasenames = forbiddenFileNameBasenames.map({$0.uppercased()})
        }
    }

    private var forbiddenFileNameCharactersRegex: NSRegularExpression?

    public var forbiddenFileNameCharacters: [String] = [] {
        didSet {
            forbiddenFileNameCharactersRegex = try? NSRegularExpression(pattern: "[\(forbiddenFileNameCharacters.joined())]")
        }
    }

    public var forbiddenFileNameExtensions: [String] = [] {
        didSet {
            forbiddenFileNameExtensions = forbiddenFileNameExtensions.map({$0.uppercased()})
        }
    }

    public let fileEndsWithSpacePeriodError = NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("_file_name_validator_error_ends_with_space_period_", value: "File name ends with a space or a period.", comment: ""))

    public var fileReservedNameError: NKError {
        let errorMessageTemplate = NSLocalizedString("_file_name_validator_error_reserved_name_", value: "%@ is a forbidden name.", comment: "")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    public var fileForbiddenFileExtensionError: NKError {
        let errorMessageTemplate = NSLocalizedString("_file_name_validator_error_forbidden_file_extension_", value: ".%@ is a forbidden file extension.", comment: "")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    public var fileInvalidCharacterError: NKError {
        let errorMessageTemplate = NSLocalizedString("file_name_validator_error_invalid_character_", value: "Name contains an invalid character: %@.", comment: "")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    private var templateString = ""

    private init() {}

    public func setup(forbiddenFileNames: [String], forbiddenFileNameBasenames: [String], forbiddenFileNameCharacters: [String], forbiddenFileNameExtensions: [String]) {
        self.forbiddenFileNames = forbiddenFileNames
        self.forbiddenFileNameBasenames = forbiddenFileNameBasenames
        self.forbiddenFileNameCharacters = forbiddenFileNameCharacters
        self.forbiddenFileNameExtensions = forbiddenFileNameExtensions
    }

    public func checkFileName(_ filename: String, existedFileNames: Set<String>? = nil) -> NKError? {
        if filename.hasSuffix(" ") || filename.hasSuffix(".") {
            return fileEndsWithSpacePeriodError
        }

        if let invalidCharacterError = checkInvalidCharacters(string: filename) {
            return invalidCharacterError
        }

        if forbiddenFileNames.contains(filename.uppercased()) || forbiddenFileNames.contains(filename.withRemovedFileExtension.uppercased()) ||
            forbiddenFileNameBasenames.contains(filename.uppercased()) || forbiddenFileNameBasenames.contains(filename.withRemovedFileExtension.uppercased()) {
            templateString = filename
            return fileReservedNameError
        }

        if forbiddenFileNameExtensions.contains(where: { filename.uppercased().hasSuffix($0.uppercased()) }) {
            templateString = filename.fileExtension
            return fileForbiddenFileExtensionError
        }

        return nil
    }

    public func checkFolderPath(folderPath: String) -> Bool {
        return folderPath.split { $0 == "/" || $0 == "\\" }
            .allSatisfy { checkFileName(String($0)) == nil }
    }

    private func checkInvalidCharacters(string: String) -> NKError? {
        for char in string {
            let charAsString = String(char)
            let range = NSRange(location: 0, length: charAsString.utf16.count)

            if forbiddenFileNameCharactersRegex?.firstMatch(in: charAsString, options: [], range: range) != nil {
                templateString = charAsString
                return fileInvalidCharacterError
            }
        }
        return nil
    }
}
