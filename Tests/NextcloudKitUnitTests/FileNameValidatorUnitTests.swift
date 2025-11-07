// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import NextcloudKit

@Suite(.serialized)
struct FileNameValidatorUnitTests {
    private func makeFileNameValidator(serverMajor: Int = 32, wcfEnabled: Bool = true) -> FileNameValidator {
        let capabilities = NKCapabilities.Capabilities()
        capabilities.windowsCompatibleFilenamesEnabled = wcfEnabled
        capabilities.serverVersionMajor = serverMajor

        capabilities.forbiddenFileNames = [".htaccess",".htaccess"]
        capabilities.forbiddenFileNameBasenames = ["con", "prn", "aux", "nul", "com0", "com1", "com2", "com3", "com4",
                                                   "com5", "com6", "com7", "com8", "com9", "com¹", "com²", "com³",
                                                   "lpt0", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7",
                                                   "lpt8", "lpt9", "lpt¹", "lpt²", "lpt³"]
        capabilities.forbiddenFileNameCharacters = ["<", ">", ":", "\\\\", "/", "|", "?", "*", "&"]
        capabilities.forbiddenFileNameExtensions = [".filepart",".part", ".", ",", " "]

        return FileNameValidator(capabilities: capabilities)
    }

    @Test("Invalid character is rejected")
    func invalidCharacter() async throws {
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFileName("file<name")
        #expect(result?.errorDescription == fileNameValidator.fileInvalidCharacterError(templateString: "<").errorDescription)
    }

    @Test("Reserved name is rejected")
    func reservedName() async throws {
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFileName("CON")
        #expect(result?.errorDescription == fileNameValidator.fileReservedNameError(templateString: "CON").errorDescription)
    }

    @Test("Forbidden filename extension is rejected")
    func forbiddenFilenameExtension() async throws {
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFileName("my_fav_file.filepart")
        #expect(result?.errorDescription == fileNameValidator.fileForbiddenFileExtensionError(templateString: "filepart").errorDescription)
    }

    @Test("Ending with space or period is rejected appropriately")
    func endsWithSpaceOrPeriod() async throws {
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFileName("filename ")
        #expect(result?.errorDescription == fileNameValidator.fileWithSpaceError().errorDescription)

        let result2 = fileNameValidator.checkFileName("filename.")
        #expect(result2?.errorDescription == fileNameValidator.fileForbiddenFileExtensionError(templateString: "").errorDescription)

        let result3 = fileNameValidator.checkFileName(" filename")
        #expect(result3?.errorDescription == fileNameValidator.fileWithSpaceError().errorDescription)

        let result4 = fileNameValidator.checkFileName(" filename. ")
        #expect(result4?.errorDescription == fileNameValidator.fileWithSpaceError().errorDescription)
    }

    @Test("Valid file names pass")
    func validFileName() async throws {
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFileName("validFileName")
        #expect(result?.errorDescription == nil)

        let result2 = fileNameValidator.checkFileName("validFi.leName")
        #expect(result2?.errorDescription == nil)

        let result3 = fileNameValidator.checkFileName("validFi.leName.txt")
        #expect(result3?.errorDescription == nil)

        let result4 = fileNameValidator.checkFileName("validFi   leName.txt")
        #expect(result4?.errorDescription == nil)
    }

    @Test("Valid folder path passes")
    func validFolderAndFilePaths() async throws {
        let folderPath = "validFolder"
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(result)
    }

    @Test("Folder path with reserved name fails")
    func folderPathWithReservedName() async throws {
        let folderPath = "CON"
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result)
    }

    @Test("Folder path with invalid character fails")
    func folderPathWithInvalidCharacter() async throws {
        let folderPath = "invalid<Folder"
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result)
    }

    @Test("Folder path ending with space fails")
    func folderPathEndingWithSpace() async throws {
        let folderPath = "folderWithSpace "
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result)
    }

    @Test("Folder path ending with period fails")
    func folderPathEndingWithPeriod() async throws {
        let folderPath = "validFolder."
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result)
    }

    @Test("Nested folder and file path checks")
    func filePathWithNestedFolder() async throws {
        let folderPath = "validFolder/secondValidFolder/CON"
        let fileNameValidator = makeFileNameValidator()
        let filePaths = ["file1.txt", "file2.doc", "file3."]

        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result)

        filePaths.forEach { path in
            let result = fileNameValidator.checkFileName(path)

            if path == "file3." {
                #expect(result?.errorDescription != nil)
            } else {
                #expect(result?.errorDescription == nil)
            }
        }
    }

    @Test("Only folder path passes")
    func onlyFolderPath() async throws {
        let folderPath = "/A1/Aaaww/W/C2/"
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(result)
    }

    @Test("Only folder path with reserved name fails")
    func onlyFolderPathWithOneReservedName() async throws {
        let folderPath = "/A1/Aaaww/CON/W/C2/"
        let fileNameValidator = makeFileNameValidator()
        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result)
    }

    @Test("Empty file names are rejected and folder path invalid")
    func fileNameEmpty() async throws {
        let folderPath = "/A1/Aaaww/W/   "
        let fileNameValidator = makeFileNameValidator()
        let filePaths = ["", " ", "  ", "               "]

        let result = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result)

        filePaths.forEach { path in
            let result = fileNameValidator.checkFileName(path)
            #expect(result?.errorDescription != nil)
        }
    }

    @Test("Skip validation when WCF disabled")
    func skipValidateWhenWCFDisabled() async throws {
        let fileNameValidator = makeFileNameValidator(serverMajor: 32, wcfEnabled: false)
        let folderPath = "validFolder/secondValidFolder/CON"
        let filePath = "file3."

        let result = fileNameValidator.checkFileName(filePath)
        #expect(result == nil)

        let result2 = fileNameValidator.checkFolderPath(folderPath)
        #expect(result2)
    }

    @Test("When WCF is enabled AND version is >=32, validator returns errors for invalid filenames")
    func doValidateWhenWCFEnabled() async throws {
        let fileNameValidator = makeFileNameValidator(serverMajor: 32, wcfEnabled: true)
        let folderPath = "validFolder/secondValidFolder/CON"
        let filePath = "file3."

        let result = fileNameValidator.checkFileName(filePath)
        #expect(result != nil)

        let result2 = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result2)
    }

    @Test("When WCF is disabled AND version is >=32, validator returns no errors for invalid filenames")
    func skipValidateWhenWCFEnabled() async throws {
        let fileNameValidator = makeFileNameValidator(serverMajor: 32, wcfEnabled: false)
        let folderPath = "validFolder/secondValidFolder/CON"
        let filePath = "file3."

        let result = fileNameValidator.checkFileName(filePath)
        #expect(result == nil)

        let result2 = fileNameValidator.checkFolderPath(folderPath)
        #expect(result2)
    }

    @Test("When WCF is disabled BUT version is 31, the filename should be returned modified. Flag is ignored.")
    func doValidateWhenVersion31() {
        let fileNameValidator = makeFileNameValidator(serverMajor: 31, wcfEnabled: false)
        let folderPath = "validFolder/secondValidFolder/CON"
        let filePath = "file3."

        let result = fileNameValidator.checkFileName(filePath)
        #expect(result != nil)

        let result2 = fileNameValidator.checkFolderPath(folderPath)
        #expect(!result2)
    }

    @Test("When WCF is disabled BUT version is 31, the filename should be returned modified. Flag is ignored.")
    func skipValidateWhenVersion29() {
        let fileNameValidator = makeFileNameValidator(serverMajor: 29, wcfEnabled: true)
        let folderPath = "validFolder/secondValidFolder/CON"
        let filePath = "file3."

        let result = fileNameValidator.checkFileName(filePath)
        #expect(result == nil)

        let result2 = fileNameValidator.checkFolderPath(folderPath)
        #expect(result2)
    }
}

