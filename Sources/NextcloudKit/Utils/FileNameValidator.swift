// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public final class FileNameValidator: Sendable {
    private let forbiddenFileNames: [String]
    private let forbiddenFileNameBasenames: [String]
    private let forbiddenFileNameCharacters: [String]
    private let forbiddenFileNameExtensions: [String]
    private let capabilities: NKCapabilities.Capabilities

    public func fileEmptyNameError() -> NKError {
        NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("File name cannot be empty.", bundle: .module, comment: "Error message when a file or folder name is empty."))
    }

    public func fileWithSpaceError() -> NKError {
        NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("Name must not contain spaces at the beginning or end.", bundle: .module, comment: "Error message when a name starts or ends with a space."))
    }

    public func fileReservedNameError(templateString: String) -> NKError {
        let errorMessageTemplate = NSLocalizedString("\"%@\" is a forbidden name.", bundle: .module, comment: "Error message when the server reserves a name. %@ is the name.")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    public func fileForbiddenFileExtensionError(templateString: String) -> NKError {
        let errorMessageTemplate = NSLocalizedString("\".%@\" is a forbidden file extension.", bundle: .module, comment: "Error message when the server forbids a file extension. %@ is the extension.")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    public func fileInvalidCharacterError(templateString: String) -> NKError {
        let errorMessageTemplate = NSLocalizedString("Name contains an invalid character: \"%@\".", bundle: .module, comment: "Error message when a name contains a forbidden character. %@ is the character.")
        let errorMessage = String(format: errorMessageTemplate, templateString)
        return NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: errorMessage)
    }

    public init(capabilities: NKCapabilities.Capabilities) {
        self.forbiddenFileNames = capabilities.forbiddenFileNames.map { $0.uppercased() }
        self.forbiddenFileNameBasenames = capabilities.forbiddenFileNameBasenames.map { $0.uppercased() }
        self.forbiddenFileNameCharacters = capabilities.forbiddenFileNameCharacters
        self.forbiddenFileNameExtensions = capabilities.forbiddenFileNameExtensions.map { $0.uppercased() }
        self.capabilities = capabilities
    }

    public func checkFileName(_ filename: String) -> NKError? {
        if !capabilities.shouldEnforceWindowsCompatibleFilenames {
            return nil
        }

        if filename.trimmingCharacters(in: .whitespaces).isEmpty {
            return fileEmptyNameError()
        }

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

    public static func isFileHidden(_ name: String) -> Bool {
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
