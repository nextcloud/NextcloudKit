// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum NKEditorDetailsConverter {

    /// Parses and converts raw JSON `Data` into `[NKEditorDetailsEditors]` and `[NKEditorDetailsCreators]`.
    /// - Parameter data: Raw JSON `Data` from the editors/creators endpoint.
    /// - Returns: A tuple with editors and creators.
    /// - Throws: Decoding error if parsing fails.
    public static func from(data: Data) throws -> (editors: [NKEditorDetailsEditor], creators: [NKEditorDetailsCreator]) {
        let decoded = try JSONDecoder().decode(NKEditorDetailsResponse.self, from: data)
        let editors = decoded.ocs.data.editorsArray()
        let creators = decoded.ocs.data.creatorsArray()

        if NKLogFileManager.shared.logLevel == .verbose {
            data.printJson()
        }
        
        return (editors, creators)
    }
}
