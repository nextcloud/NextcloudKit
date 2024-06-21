//
//  NextcloudKit+API_Async.swift
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

#if os(macOS)
import Foundation
import AppKit
#else
import UIKit
#endif

@available(iOS 13.0, *)
extension NextcloudKit {

    public func getServerStatus(serverUrl: String,
                                options: NKRequestOptions = NKRequestOptions()) async -> (ServerInfoResult) {

        await withUnsafeContinuation({ continuation in
            getServerStatus(serverUrl: serverUrl) { serverInfoResult in
                continuation.resume(returning: serverInfoResult)
            }
        })
    }

    public func getPreview(url: URL,
                           options: NKRequestOptions = NKRequestOptions()) async -> (account: String, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            getPreview(url: url, options: options) { account, data, error in
                continuation.resume(returning: (account: account, data: data, error: error))
            }
        })
    }

    public func downloadPreview(fileId: String,
                                fileNamePreviewLocalPath: String,
                                fileNameIconLocalPath: String? = nil,
                                widthPreview: Int,
                                heightPreview: Int,
                                sizeIcon: Int,
                                etag: String? = nil,
                                crop: Int = 0,
                                cropMode: String = "fill",
                                forceIcon: Int = 1,
                                mimeFallback: Int = 0,
                                options: NKRequestOptions = NKRequestOptions()) async -> (account: String, imagePreview: UIImage?, imageIcon: UIImage?, imageOriginal: UIImage?, etag: String?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            downloadPreview(fileId: fileId, fileNamePreviewLocalPath: fileNamePreviewLocalPath, fileNameIconLocalPath: fileNameIconLocalPath, widthPreview: widthPreview, heightPreview: heightPreview, sizeIcon: sizeIcon, etag: etag, crop: crop, cropMode: cropMode, forceIcon: forceIcon, mimeFallback: mimeFallback, options: options) { account, imagePreview, imageIcon, imageOriginal, etag, error in
                continuation.resume(returning: (account: account, imagePreview: imagePreview, imageIcon: imageIcon, imageOriginal: imageOriginal, etag: etag, error: error))
            }
        })
    }

    public func getUserProfile(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, userProfile: NKUserProfile?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            getUserProfile(options: options) { account, userProfile, data, error in
                continuation.resume(returning: (account: account, userProfile: userProfile, data: data, error: error))
            }
        })
    }

    public func sendClientDiagnosticsRemoteOperation(data: Data,
                                                     options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {

        await withUnsafeContinuation({ continuation in
            sendClientDiagnosticsRemoteOperation(data: data, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }
}
