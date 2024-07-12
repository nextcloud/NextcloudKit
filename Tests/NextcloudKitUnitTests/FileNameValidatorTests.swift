//
//  FileNameValidatorTests.swift
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

    var capability: OCCapability!

    override func setUp() {
        super.setUp()
        capability = OCCapability()
        capability.forbiddenFilenames = true
        capability.forbiddenFilenameExtension = true
        capability.forbiddenFilenameCharacters = true
    }

    func testInvalidCharacter() {
        let result = FileNameValidator.checkFileName("file<name", capability: capability)
        XCTAssertEqual(result?.error as? NKError, FileNameValidator.emptyFilenameError)
    }

    func testReservedName() {
        let result = FileNameValidator.checkFileName("CON", capability: capability)
        XCTAssertEqual(result?.error as? NKError, FileNameValidator.fileReservedNameError)
    }

    func testEndsWithSpaceOrPeriod() {
        let result = FileNameValidator.checkFileName("filename ", capability: capability)
        XCTAssertEqual(result?.error as? NKError, FileNameValidator.fileEndsWithSpacePeriodError)

        let result2 = FileNameValidator.checkFileName("filename.", capability: capability)
        XCTAssertEqual(result?.error as? NKError, FileNameValidator.fileEndsWithSpacePeriodError)
    }

    func testEmptyFileName() {
        let result = FileNameValidator.checkFileName("", capability: capability)
        XCTAssertEqual(result?.error as? NKError, FileNameValidator.emptyFilenameError)
    }

    func testFileAlreadyExists() {
        let existingFiles: Set<String> = ["existingFile"]
        let result = FileNameValidator.checkFileName("existingFile", capability: capability, existedFileNames: existingFiles)
        XCTAssertEqual(result?.error as? NKError, FileNameValidator.fileAlreadyExistsError)
    }

    func testValidFileName() {
        let result = FileNameValidator.checkFileName("validFileName", capability: capability)
        XCTAssertNil(result)
    }

    func testIsFileHidden() {
        XCTAssertTrue(FileNameValidator.isFileHidden(name: ".hiddenFile"))
        XCTAssertFalse(FileNameValidator.isFileHidden(name: "visibleFile"))
    }

    func testIsFileNameAlreadyExist() {
        let existingFiles: Set<String> = ["existingFile"]
        XCTAssertTrue(FileNameValidator.isFileNameAlreadyExist("existingFile", fileNames: existingFiles))
        XCTAssertFalse(FileNameValidator.isFileNameAlreadyExist("newFile", fileNames: existingFiles))
    }

    func testValidFolderAndFilePaths() {
        let folderPath = "validFolder"
        let filePaths = ["file1.txt", "file2.doc", "file3.jpg"]

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths, capability: capability)
        XCTAssertTrue(result)
    }

    func testFolderPathWithReservedName() {
        let folderPath = "CON"
        let filePaths = ["file1.txt", "file2.doc", "file3.jpg"]

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths, capability: capability)
        XCTAssertFalse(result)
    }

    func testFilePathWithReservedName() {
        let folderPath = "validFolder"
        let filePaths = ["file1.txt", "PRN.doc", "file3.jpg"]

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths, capability: capability)
        XCTAssertFalse(result)
    }

    func testFolderPathWithInvalidCharacter() {
        let folderPath = "invalid<Folder"
        let filePaths = ["file1.txt", "file2.doc", "file3.jpg"]

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths, capability: capability)
        XCTAssertFalse(result)
    }

    func testFilePathWithInvalidCharacter() {
        let folderPath = "validFolder"
        let filePaths = ["file1.txt", "file|2.doc", "file3.jpg"]

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths, capability: capability)
        XCTAssertFalse(result)
    }

    func testFolderPathEndingWithSpace() {
        let folderPath = "folderWithSpace "
        let filePaths = ["file1.txt", "file2.doc", "file3.jpg"]

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths, capability: capability)
        XCTAssertFalse(result)
    }

    func testFilePathEndingWithPeriod() {
        let folderPath = "validFolder"
        let filePaths = ["file1.txt", "file2.doc", "file3."]

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths, capability: capability)
        XCTAssertFalse(result)
    }

    func testFilePathWithNestedFolder() {
        let folderPath = "validFolder/secondValidFolder/CON"
        let filePaths = ["file1.txt", "file2.doc", "file3."]

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: filePaths, capability: capability)
        XCTAssertFalse(result)
    }

    func testOnlyFolderPath() {
        let folderPath = "/A1/Aaaww/W/C2/"

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: [], capability: capability)
        XCTAssertTrue(result)
    }

    func testOnlyFolderPathWithOneReservedName() {
        let folderPath = "/A1/Aaaww/CON/W/C2/"

        let result = FileNameValidator.checkFolderAndFilePaths(folderPath: folderPath, filePaths: [], capability: capability)
        XCTAssertFalse(result)
    }
}
