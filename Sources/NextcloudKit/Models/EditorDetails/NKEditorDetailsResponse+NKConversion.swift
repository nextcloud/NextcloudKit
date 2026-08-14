// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public extension NKDirectEditingCapabilitiesResponse.OCS.DataClass {
    func editorsArray() -> [NKDirectEditingEditor] {
        Array(editors.values)
    }

    func creatorsArray() -> [NKDirectEditingCreator] {
        Array(creators.values)
    }
}
