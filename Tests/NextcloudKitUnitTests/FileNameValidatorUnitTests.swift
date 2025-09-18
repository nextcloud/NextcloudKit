// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import NextcloudKit

class FileNameValidatorUnitTests: XCTestCase {
    var fileNameValidator: FileNameValidator!

    override func setUp() {
        fileNameValidator = FileNameValidator(
            forbiddenFileNames: [".htaccess",".htaccess"],
            forbiddenFileNameBasenames: ["con", "prn", "aux", "nul", "com0", "com1", "com2", "com3", "com4",
                                         "com5", "com6", "com7", "com8", "com9", "com¹", "com²", "com³",
                                         "lpt0", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7",
                                         "lpt8", "lpt9", "lpt¹", "lpt²", "lpt³"],
            forbiddenFileNameCharacters: ["<", ">", ":", "\\\\", "/", "|", "?", "*", "&"],
            forbiddenFileNameExtensions: [".filepart",".part", ".", ",", " "]
        )
        super.setUp()
    }

    func testInvalidCharacter() {
        let result = fileNameValidator.checkFileName("file<name")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileInvalidCharacterError(templateString: "<").errorDescription)
    }

    func testReservedName() {
        let result = fileNameValidator.checkFileName("CON")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileReservedNameError(templateString: "CON").errorDescription)
    }

    func testForbiddenFilenameExtension() {
        let result = fileNameValidator.checkFileName("my_fav_file.filepart")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileForbiddenFileExtensionError(templateString: "filepart").errorDescription)
    }

    func testEndsWithSpaceOrPeriod() {
        let result = fileNameValidator.checkFileName("filename ")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileWithSpaceError().errorDescription)

        let result2 = fileNameValidator.checkFileName("filename.")
        XCTAssertEqual(result2?.errorDescription, fileNameValidator.fileForbiddenFileExtensionError(templateString: "").errorDescription)

        let result3 = fileNameValidator.checkFileName(" filename")
        XCTAssertEqual(result3?.errorDescription, fileNameValidator.fileWithSpaceError().errorDescription)

        let result4 = fileNameValidator.checkFileName(" filename. ")
        XCTAssertEqual(result4?.errorDescription, fileNameValidator.fileWithSpaceError().errorDescription)
    }

    func testValidFileName() {
        let result = fileNameValidator.checkFileName("validFileName")
        XCTAssertNil(result?.errorDescription)

        let result2 = fileNameValidator.checkFileName("validFi.leName")
        XCTAssertNil(result2?.errorDescription)

        let result3 = fileNameValidator.checkFileName("validFi.leName.txt")
        XCTAssertNil(result3?.errorDescription)

        let result4 = fileNameValidator.checkFileName("validFi   leName.txt")
        XCTAssertNil(result4?.errorDescription)
    }

    func testValidFolderAndFilePaths() {
        let folderPath = "validFolder"

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertTrue(result)
    }

    func testFolderPathWithReservedName() {
        let folderPath = "CON"

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertFalse(result)
    }

    func testFolderPathWithInvalidCharacter() {
        let folderPath = "invalid<Folder"

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertFalse(result)
    }

    func testFolderPathEndingWithSpace() {
        let folderPath = "folderWithSpace "

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertFalse(result)
    }

    func testFolderPathEndingWithPeriod() {
        let folderPath = "validFolder."

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertFalse(result)
    }

    func testFilePathWithNestedFolder() {
        let folderPath = "validFolder/secondValidFolder/CON"
        let filePaths = ["file1.txt", "file2.doc", "file3."]

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertFalse(result)

        filePaths.forEach { path in
            let result = fileNameValidator.checkFileName(path)

            if path == "file3." {
                XCTAssertNotNil(result?.errorDescription)
            } else {
                XCTAssertNil(result?.errorDescription)
            }
        }
    }

    func testOnlyFolderPath() {
        let folderPath = "/A1/Aaaww/W/C2/"

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertTrue(result)
    }

    func testOnlyFolderPathWithOneReservedName() {
        let folderPath = "/A1/Aaaww/CON/W/C2/"

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertFalse(result)
    }

    func testFileNameEmpty() {
        let folderPath = "/A1/Aaaww/W/   "
        let filePaths = ["", " ", "  ", "               "]

        let result = fileNameValidator.checkFolderPath(folderPath)
        XCTAssertFalse(result)

        filePaths.forEach { path in
            let result = fileNameValidator.checkFileName(path)

            XCTAssertNotNil(result?.errorDescription)
        }
    }
}
