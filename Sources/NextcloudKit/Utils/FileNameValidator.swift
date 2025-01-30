// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public final class FileNameValidator: Sendable {
    private let forbiddenFileNames: [String]
    private let forbiddenFileNameBasenames: [String]
    private let forbiddenFileNameCharacters: [String]
    private let forbiddenFileNameExtensions: [String]

    public func fileWithSpaceError() -> NKError {
        NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("_file_name_validator_error_space_", value: "Name must not contain spaces at the beginning or end.", comment: ""))
    }

    public func fileReservedNameError(templateString: String) -> NKError {
        let errorMessageTemplate = NSLocalizedString("_file_name_validator_error_reserved_name_", value: "\"%@\" is a forbidden name.", comment: "")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    public func fileForbiddenFileExtensionError(templateString: String) -> NKError {
        let errorMessageTemplate = NSLocalizedString("_file_name_validator_error_forbidden_file_extension_", value: ".\"%@\" is a forbidden file extension.", comment: "")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    public func fileInvalidCharacterError(templateString: String) -> NKError {
        let errorMessageTemplate = NSLocalizedString("_file_name_validator_error_invalid_character_", value: "Name contains an invalid character: \"%@\".", comment: "")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    public init(forbiddenFileNames: [String], forbiddenFileNameBasenames: [String], forbiddenFileNameCharacters: [String], forbiddenFileNameExtensions: [String]) {
        self.forbiddenFileNames = forbiddenFileNames.map { $0.uppercased() }
        self.forbiddenFileNameBasenames = forbiddenFileNameBasenames.map { $0.uppercased() }
        self.forbiddenFileNameCharacters = forbiddenFileNameCharacters
        self.forbiddenFileNameExtensions = forbiddenFileNameExtensions.map { $0.uppercased() }
    }

    public func checkFileName(_ filename: String) -> NKError? {
        if let regex = try? NSRegularExpression(pattern: "[\(forbiddenFileNameCharacters.joined())]"), let invalidCharacterError = checkInvalidCharacters(string: filename, regex: regex) {
            return invalidCharacterError
        }

        if forbiddenFileNames.contains(filename.uppercased()) || forbiddenFileNames.contains(filename.withRemovedFileExtension.uppercased()) ||
            forbiddenFileNameBasenames.contains(filename.uppercased()) || forbiddenFileNameBasenames.contains(filename.withRemovedFileExtension.uppercased()) {
            return fileReservedNameError(templateString: filename)
        }

        for fileNameExtension in forbiddenFileNameExtensions {
            if fileNameExtension == " " {
                if filename.uppercased().hasSuffix(fileNameExtension) || filename.uppercased().hasPrefix(fileNameExtension) {
                    return fileWithSpaceError()
                }
            } else if filename.uppercased().hasSuffix(fileNameExtension.uppercased()) {
                if fileNameExtension == " " {
                    return fileWithSpaceError()
                }

                return fileForbiddenFileExtensionError(templateString: filename.fileExtension)
            }
        }

        return nil
    }

    public func checkFolderPath(_ folderPath: String) -> Bool {
        return folderPath.split { $0 == "/" || $0 == "\\" }
            .allSatisfy { checkFileName(String($0)) == nil }
    }

    public func isFileHidden(_ name: String) -> Bool {
        return !name.isEmpty && name.first == "."
    }

    private func checkInvalidCharacters(string: String, regex: NSRegularExpression) -> NKError? {
        for char in string {
            let charAsString = String(char)
            let range = NSRange(location: 0, length: charAsString.utf16.count)

            if regex.firstMatch(in: charAsString, options: [], range: range) != nil {
                return fileInvalidCharacterError(templateString: charAsString)
            }
        }
        return nil
    }
}
