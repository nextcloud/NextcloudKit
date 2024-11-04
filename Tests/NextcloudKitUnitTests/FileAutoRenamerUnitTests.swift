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
        let filename = "file\(forbiddenFilenameCharacter)file.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "file_file.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testInvalidExtension() {
        let filename = "file\(forbiddenFilenameExtension)"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "file_"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testMultipleInvalidChars() {
        let filename = "file|name?<>.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "file_name___.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartEndInvalidExtensions() {
        let filename = " .file.part "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_file_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartEndInvalidExtensions2() {
        fileAutoRenamer.setup(
            forbiddenFileNameCharacters: initialCharacters,
            forbiddenFileNameExtensions: [",", ".", ".filepart", ".part", " "]
        )

        let filename = " .file.part "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_file_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartEndInvalidExtensions3() {
        fileAutoRenamer.setup(
            forbiddenFileNameCharacters: initialCharacters,
            forbiddenFileNameExtensions: [".FILEPART", ".PART", " ", ",", "."]
        )

        let filename = " .file.part "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_file_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartInvalidExtension() {
        let filename = " .file.part"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_file_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testEndInvalidExtension() {
        let filename = ".file.part "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "_file_part"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testMiddleNonPrintableChar() {
        let filename = "file\u{0001}name.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartNonPrintableChar() {
        let filename = "\u{0001}filename.txt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testEndNonPrintableChar() {
        let filename = "filename.txt\u{0001}"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testExtensionNonPrintableChar() {
        let filename = "filename.t\u{0001}xt"
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "filename.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testMiddleInvalidFolderChar() {
        let folderPath = "abc/def/kg\(forbiddenFilenameCharacter)/lmo/pp"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "abc/def/kg_/lmo/pp"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }

    func testEndInvalidFolderChar() {
        let folderPath = "abc/def/kg/lmo/pp\(forbiddenFilenameCharacter)"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "abc/def/kg/lmo/pp_"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }

    func testStartInvalidFolderChar() {
        let folderPath = "\(forbiddenFilenameCharacter)abc/def/kg/lmo/pp"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "_abc/def/kg/lmo/pp"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }

    func testMixedInvalidChar() {
        let filename = " file\u{0001}na\(forbiddenFilenameCharacter)me.txt "
        let result = fileAutoRenamer.rename(filename: filename)
        let expectedFilename = "filena_me.txt"
        XCTAssertEqual(result, expectedFilename, "Expected \(expectedFilename) but got \(result)")
    }

    func testStartsWithPathSeparator() {
        let folderPath = "/abc/def/kg/lmo/pp\(forbiddenFilenameCharacter)/file.txt/"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "/abc/def/kg/lmo/pp_/file.txt/"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }

    func testStartsWithPathSeparatorAndValidFilepath() {
        let folderPath = "/COm02/2569.webp"
        let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
        let expectedFolderName = "/COm02/2569.webp"
        XCTAssertEqual(result, expectedFolderName, "Expected \(expectedFolderName) but got \(result)")
    }
}

