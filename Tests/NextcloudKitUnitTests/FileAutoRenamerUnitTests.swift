// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import NextcloudKit

@Suite(.serialized)
struct FileAutoRenamerUnitTests {
    let forbiddenFilenameCharacter = ">"
    let forbiddenFilenameExtension = "."

    let characterArrays = [
        ["\\\\", "*", ">", "&", "/", "|", ":", "<", "?", " "],
        [">", ":", "?", " ", "&", "*", "\\\\", "|", "<", "/"],
        ["<", "|", "?", ":", "&", "*", "\\\\", " ", "/", ">"],
        ["?", "/", " ", ":", "&", "<", "|", ">", "\\\\", "*"],
        ["&", "<", "|", "*", "/", "?", ">", " ", ":", "\\\\"]
    ]

    let extensionArrays = [
        [" ", ",", ".", ".filepart", ".part"],
        [".filepart", ".part", " ", ".", ","],
        [".PART", ".", ",", " ", ".filepart"],
        [",", " ", ".FILEPART", ".part", "."],
        [".", ".PART", ",", " ", ".FILEPART"]
    ]

    let combinedTuples: [([String], [String])]

    init() {
        combinedTuples = zip(characterArrays, extensionArrays).map { ($0, $1) }
    }

    private func makeAutoRenamer(chars: [String], exts: [String], wcfEnabled: Bool = true, serverMajor: Int = 32) -> FileAutoRenamer {
        let capabilities = NKCapabilities.Capabilities()
        capabilities.windowsCompatibleFilenamesEnabled = wcfEnabled
        capabilities.serverVersionMajor = serverMajor

        capabilities.forbiddenFileNameCharacters = chars
        capabilities.forbiddenFileNameExtensions = exts

        return FileAutoRenamer(capabilities: capabilities)
    }

    @Test func testInvalidChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = "File\(forbiddenFilenameCharacter)File.txt"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "File_File.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testInvalidExtension() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = "File\(forbiddenFilenameExtension)"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "File_"
            #expect(result == expectedFilename)
        }
    }

    @Test func testMultipleInvalidChars() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = "File|name?<>.txt"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "File_name___.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testStartEndInvalidExtensions() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = " .File.part "
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "_File_part"
            #expect(result == expectedFilename)
        }
    }

    @Test func testStartInvalidExtension() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = " .File.part"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "_File_part"
            #expect(result == expectedFilename)
        }
    }

    @Test func testEndInvalidExtension() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = ".File.part "
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "_File_part"
            #expect(result == expectedFilename)
        }
    }

    @Test func testHiddenFile() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = ".Filename.txt"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "_Filename.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testUppercaseExtension() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = ".Filename.TXT"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "_Filename.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testMiddleNonPrintableChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = "File\u{0001}name.txt"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "Filename.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testStartNonPrintableChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = "\u{0001}Filename.txt"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "Filename.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testEndNonPrintableChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = "Filename.txt\u{0001}"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "Filename.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testExtensionNonPrintableChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = "Filename.t\u{0001}xt"
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "Filename.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testMiddleInvalidFolderChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let folderPath = "Abc/Def/kg\(forbiddenFilenameCharacter)/lmo/pp"
            let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
            let expectedFolderName = "Abc/Def/kg_/lmo/pp"
            #expect(result == expectedFolderName)
        }
    }

    @Test func testEndInvalidFolderChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let folderPath = "Abc/Def/kg/lmo/pp\(forbiddenFilenameCharacter)"
            let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
            let expectedFolderName = "Abc/Def/kg/lmo/pp_"
            #expect(result == expectedFolderName)
        }
    }

    @Test func testStartInvalidFolderChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let folderPath = "\(forbiddenFilenameCharacter)Abc/Def/kg/lmo/pp"
            let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
            let expectedFolderName = "_Abc/Def/kg/lmo/pp"
            #expect(result == expectedFolderName)
        }
    }

    @Test func testMixedInvalidChar() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let filename = " File\u{0001}na\(forbiddenFilenameCharacter)me.txt "
            let result = fileAutoRenamer.rename(filename: filename)
            let expectedFilename = "Filena_me.txt"
            #expect(result == expectedFilename)
        }
    }

    @Test func testStartsWithPathSeparator() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)

            let folderPath = "/Abc/Def/kg/lmo/pp\(forbiddenFilenameCharacter)/File.txt/"
            let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
            let expectedFolderName = "/Abc/Def/kg/lmo/pp_/File.txt/"
            #expect(result == expectedFolderName)
        }
    }

    @Test func testStartsWithPathSeparatorAndValidFilepath() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray)
            
            let folderPath = "/COm02/2569.webp"
            let result = fileAutoRenamer.rename(filename: folderPath, isFolderPath: true)
            let expectedFolderName = "/COm02/2569.webp"
            #expect(result == expectedFolderName)
        }
    }

    @Test("When WCF is disabled AND version is >=32, the filename should be returned unchanged.")
    func skipAutoRenameWhenWCFDisabled() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray, wcfEnabled: false, serverMajor: 32)

            let filename = "   readme.txt  "
            let result = fileAutoRenamer.rename(filename: filename, isFolderPath: true)
            #expect(result == filename)
        }
    }

    @Test("When WCF is enabled AND version is >=32, the filename should be returned modified.")
    func doAutoRenameWhenWCFEnabled() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray, wcfEnabled: true, serverMajor: 32)

            let filename = "   readme.txt  "
            let result = fileAutoRenamer.rename(filename: filename, isFolderPath: true)
            #expect(result != filename)
        }
    }

    @Test("When WCF is disabled BUT version is 31, the filename should be returned modified. Flag is ignored.")
    func doAutoRenameWhenVersion31() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray, wcfEnabled: false, serverMajor: 31)

            let filename = "   readme.txt  "
            let result = fileAutoRenamer.rename(filename: filename, isFolderPath: true)
            #expect(result != filename)
        }
    }

    @Test("When WCF is enabled BUT version is 29, the filename should be returned unchanged. Flag is ignored.")
    func skipAutoRenameWhenVersion29() {
        for (characterArray, extensionArray) in combinedTuples {
            let fileAutoRenamer = makeAutoRenamer(chars: characterArray, exts: extensionArray, wcfEnabled: true, serverMajor: 29)

            let filename = "   readme.txt  "
            let result = fileAutoRenamer.rename(filename: filename, isFolderPath: true)
            #expect(result == filename)
        }
    }
}
