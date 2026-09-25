// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum NKDirectEditingCapabilitiesConverter {

    /// Parses and converts raw JSON `Data` into `[NKDirectEditingEditor]` and `[NKDirectEditingCreator]`.
    /// - Parameter data: Raw JSON `Data` from the editors/creators endpoint.
    /// - Returns: A tuple with editors and creators.
    /// - Throws: Decoding error if parsing fails.
    public static func from(data: Data) throws -> (editors: [NKDirectEditingEditor], creators: [NKDirectEditingCreator]) {
        let decoded = try JSONDecoder().decode(NKDirectEditingCapabilitiesResponse.self, from: data)
        let editors = Array(decoded.ocs.data.editors.values)
        let creators = Array(decoded.ocs.data.creators.values)

        if NKLogFileManager.shared.logLevel == .verbose {
            data.printJson()
        }
        
        return (editors, creators)
    }
}
