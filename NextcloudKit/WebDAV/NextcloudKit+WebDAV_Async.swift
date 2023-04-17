//
//  NextcloudKit+WebDAV_Async.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 19/10/22.
//
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
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

import Foundation

@available(iOS 13.0, *)
extension NextcloudKit {

    public func createFolder(serverUrlFileName: String,
                             options: NKRequestOptions = NKRequestOptions()) async -> (account: String, ocId: String?, date: NSDate?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            createFolder(serverUrlFileName: serverUrlFileName, options: options) { account, ocId, date, error in
                continuation.resume(returning: (account: account, ocId: ocId, date: date, error: error))
            }
        })
    }

    public func deleteFileOrFolder(serverUrlFileName: String,
                                   options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {

        await withUnsafeContinuation({ continuation in
            deleteFileOrFolder(serverUrlFileName: serverUrlFileName, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    public func readFileOrFolder(serverUrlFileName: String,
                                 depth: String,
                                 showHiddenFiles: Bool = true,
                                 requestBody: Data? = nil,
                                 options: NKRequestOptions = NKRequestOptions()) async -> (account: String, files: [NKFile], data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: depth, showHiddenFiles: showHiddenFiles, requestBody: requestBody, options: options) { account, files, data, error in
                continuation.resume(returning: (account: account, files: files, data: data, error: error))
            }
        })
    }
}
