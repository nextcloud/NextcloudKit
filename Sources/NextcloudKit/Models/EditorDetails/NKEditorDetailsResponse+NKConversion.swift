// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public extension NKEditorDetailsResponse.OCS.DataClass {
    func editorsArray() -> [NKEditorDetailsEditor] {
        Array(editors.values)
    }

    func creatorsArray() -> [NKEditorDetailsCreator] {
        Array(creators.values)
    }
}
