//
//  fileNameValidatorTests.swift
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

import XCTest
@testable import NextcloudKit

class FileNameValidatorTests: XCTestCase {
    let fileNameValidator = FileNameValidator.shared

    override func setUp() {
        fileNameValidator.setup(
            forbiddenFileNames: ["CON", "PRN", "AUX", "NUL", "COM0", "COM1", "COM2", "COM3", "COM4",
                                 "COM5", "COM6", "COM7", "COM8", "COM9", "COM¹", "COM²", "COM³",
                                 "LPT0", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7",
                                 "LPT8", "LPT9", "LPT¹", "LPT²", "LPT³"],
            forbiddenFileNameBasenames: [],
            forbiddenFileNameCharacters: ["<", ">", ":", "\\\\", "/", "|", "?", "*", "&"],
            forbiddenFileNameExtensions: [".filepart",".part"]
        )
        super.setUp()
    }

    func testInvalidCharacter() {
        let result = fileNameValidator.checkFileName("file<name")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileInvalidCharacterError.errorDescription)
    }

    func testReservedName() {
        let result = fileNameValidator.checkFileName("CON")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileReservedNameError.errorDescription)
    }

    func testForbiddenFilenameExtension() {
        let result = fileNameValidator.checkFileName("my_fav_file.filepart")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileForbiddenFileExtensionError.errorDescription)
    }

    func testEndsWithSpaceOrPeriod() {
        let result = fileNameValidator.checkFileName("filename ")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileEndsWithSpacePeriodError.errorDescription)

        let result2 = fileNameValidator.checkFileName("filename.")
        XCTAssertEqual(result2?.errorDescription, fileNameValidator.fileEndsWithSpacePeriodError.errorDescription)
    }

    func testEmptyFileName() {
        let result = fileNameValidator.checkFileName("")
        XCTAssertEqual(result?.errorDescription, fileNameValidator.emptyFilenameError.errorDescription)
    }

    func testFileAlreadyExists() {
        let existingFiles: Set<String> = ["existingFile"]
        let result = fileNameValidator.checkFileName("existingFile", existedFileNames: existingFiles)
        XCTAssertEqual(result?.errorDescription, fileNameValidator.fileAlreadyExistsError.errorDescription)
    }

    func testValidFileName() {
        let result = fileNameValidator.checkFileName("validFileName")
        XCTAssertNil(result?.errorDescription)
    }

    func testIsFileHidden() {
        XCTAssertTrue(fileNameValidator.isFileHidden(name: ".hiddenFile"))
        XCTAssertFalse(fileNameValidator.isFileHidden(name: "visibleFile"))
    }

    func testIsFileNameAlreadyExists() {
        let existingFiles: Set<String> = ["existingFile"]
        XCTAssertTrue(fileNameValidator.fileNameAlreadyExists("existingFile", fileNames: existingFiles))
        XCTAssertFalse(fileNameValidator.fileNameAlreadyExists("newFile", fileNames: existingFiles))
    }

    func testValidFolderAndFilePaths() {
        let folderPath = "validFolder"
        let filePaths = ["file1.txt", "file2.doc", "file3.jpg"]

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths)
        XCTAssertTrue(result)
    }

    func testFolderPathWithReservedName() {
        let folderPath = "CON"
        let filePaths = ["file1.txt", "file2.doc", "file3.jpg"]

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths)
        XCTAssertFalse(result)
    }

    func testFilePathWithReservedName() {
        let folderPath = "validFolder"
        let filePaths = ["file1.txt", "PRN.doc", "file3.jpg"]

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths)
        XCTAssertFalse(result)
    }

    func testFolderPathWithInvalidCharacter() {
        let folderPath = "invalid<Folder"
        let filePaths = ["file1.txt", "file2.doc", "file3.jpg"]

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths)
        XCTAssertFalse(result)
    }

    func testFilePathWithInvalidCharacter() {
        let folderPath = "validFolder"
        let filePaths = ["file1.txt", "file|2.doc", "file3.jpg"]

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths)
        XCTAssertFalse(result)
    }

    func testFolderPathEndingWithSpace() {
        let folderPath = "folderWithSpace "
        let filePaths = ["file1.txt", "file2.doc", "file3.jpg"]

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths)
        XCTAssertFalse(result)
    }

    func testFilePathEndingWithPeriod() {
        let folderPath = "validFolder"
        let filePaths = ["file1.txt", "file2.doc", "file3."]

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths)
        XCTAssertFalse(result)
    }

    func testFilePathWithNestedFolder() {
        let folderPath = "validFolder/secondValidFolder/CON"
        let filePaths = ["file1.txt", "file2.doc", "file3."]

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths)
        XCTAssertFalse(result)
    }

    func testOnlyFolderPath() {
        let folderPath = "/A1/Aaaww/W/C2/"

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: [])
        XCTAssertTrue(result)
    }

    func testOnlyFolderPathWithOneReservedName() {
        let folderPath = "/A1/Aaaww/CON/W/C2/"

        let result = fileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: [])
        XCTAssertFalse(result)
    }
}
