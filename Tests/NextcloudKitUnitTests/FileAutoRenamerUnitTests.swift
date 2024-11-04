// SPDX-FileCopyrightText: 2020 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import NextcloudKit

final class FileAutoRenamerUnitTests: XCTestCase {
    let fileAutoRenamer = FileAutoRenamer.shared

    let forbiddenFilenameCharacter = ">"
    let forbiddenFilenameExtension = "."

    let initialCharacters = ["<", ">", ":", "\\\\", "/", "|", "?", "*", "&"]
    let initialExtensions = [" ", ",", ".", ".filepart", ".part"]

    override func setUp() {
        fileAutoRenamer.setup(
            forbiddenFileNameCharacters: initialCharacters,
            forbiddenFileNameExtensions: initialExtensions
        )
        super.setUp()
    }

    func testInvalidChar() {
        let filename = "File\(forbiddenFilenameCharacter)File.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "File_File.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testInvalidExtension() {
        let filename = "File\(forbiddenFilenameExtension)"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "File_"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testMultipleInvalidChars() {
        let filename = "File|name?<>.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "File_name___.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartEndInvalidExtensions() {
        let filename = " .File.part "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_File_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartEndInvalidExtensions2() {
        fileAutoRenamer.setup(
            forbiddenFileNameCharacters: initialCharacters,
            forbiddenFileNameExtensions: [",", ".", ".filepart", ".part", " "]
        )

        let filename = " .File.part "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_File_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartEndInvalidExtensions3() {
        fileAutoRenamer.setup(
            forbiddenFileNameCharacters: initialCharacters,
            forbiddenFileNameExtensions: [".FILEPART", ".PART", " ", ",", "."]
        )

        let filename = " .File.part "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_File_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartInvalidExtension() {
        let filename = " .File.part"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_File_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testEndInvalidExtension() {
        let filename = ".File.part "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_File_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testHiddenFile() {
        let filename = ".Filename.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_Filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testUppercaseExtension() {
        let filename = ".Filename.TXT"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_Filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testMiddleNonPrintableChar() {
        let filename = "File\u{0001}name.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "Filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartNonPrintableChar() {
        let filename = "\u{0001}Filename.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "Filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testEndNonPrintableChar() {
        let filename = "Filename.txt\u{0001}"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "Filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testExtensionNonPrintableChar() {
        let filename = "Filename.t\u{0001}xt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "Filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testMiddleInvalidFolderChar() {
        let folderPath = "Abc/Def/kg\(forbiddenFilenameCharacter)/lmo/pp"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "Abc/Def/kg_/lmo/pp"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }

    func testEndInvalidFolderChar() {
        let folderPath = "Abc/Def/kg/lmo/pp\(forbiddenFilenameCharacter)"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "Abc/Def/kg/lmo/pp_"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }

    func testStartInvalidFolderChar() {
        let folderPath = "\(forbiddenFilenameCharacter)Abc/Def/kg/lmo/pp"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "_Abc/Def/kg/lmo/pp"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }

    func testMixedInvalidChar() {
        let filename = " File\u{0001}na\(forbiddenFilenameCharacter)me.txt "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "Filena_me.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartsWithPathSeparator() {
        let folderPath = "/Abc/Def/kg/lmo/pp\(forbiddenFilenameCharacter)/File.txt/"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "/Abc/Def/kg/lmo/pp_/File.txt/"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }

    func testStartsWithPathSeparatorAndValidFilepath() {
        let folderPath = "/COm02/2569.webp"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "/COm02/2569.webp"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }
}

