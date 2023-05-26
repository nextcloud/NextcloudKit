//
//  NextcloudKit+E2EE_Async.swift
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

    public func markE2EEFolder(fileId: String,
                               delete: Bool,
                               options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {

        await withUnsafeContinuation({ continuation in
            markE2EEFolder(fileId: fileId, delete: delete, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    @discardableResult
    public func lockE2EEFolder(fileId: String,
                               e2eToken: String?,
                               method: String,
                               options: NKRequestOptions = NKRequestOptions()) async -> (account: String, e2eToken: String?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            lockE2EEFolder(fileId: fileId, e2eToken: e2eToken, method: method, options: options) { account, e2eToken, data, error in
                continuation.resume(returning: (account: account, e2eToken: e2eToken, data: data, error: error))
            }
        })
    }

    public func getE2EEMetadata(fileId: String,
                                e2eToken: String?,
                                options: NKRequestOptions = NKRequestOptions()) async -> (account: String, e2eMetadata: String?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            getE2EEMetadata(fileId: fileId, e2eToken: e2eToken, options: options) { account, e2eMetadata, data, error in
                continuation.resume(returning: (account: account, e2eMetadata: e2eMetadata, data: data, error: error))
            }
        })
    }

    public func putE2EEMetadata(fileId: String,
                                e2eToken: String,
                                e2eMetadata: String?,
                                method: String,
                                options: NKRequestOptions = NKRequestOptions()) async -> (account: String, metadata: String?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, method: method, options: options) { account, metadata, data, error in
                continuation.resume(returning: (account: account, metadata: metadata, data: data, error: error))
            }
        })
    }

    public func getE2EECertificate(user: String? = nil, options: NKRequestOptions = NKRequestOptions()) async -> (account: String, certificate: String?, certificateUser: String?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            getE2EECertificate(user: user, options: options) { account, certificate, certificateUser, data, error in
                continuation.resume(returning: (account: account, certificate: certificate, certificateUser: certificateUser, data: data, error: error))
            }
        })
    }

    public func getE2EEPrivateKey(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, privateKey: String?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            getE2EEPrivateKey(options: options) { account, privateKey, data, error in
                continuation.resume(returning: (account: account, privateKey: privateKey, data: data, error: error))
            }
        })
    }

    public func getE2EEPublicKey(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, publicKey: String?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            getE2EEPublicKey(options: options) { account, publicKey, data, error in
                continuation.resume(returning: (account: account, publicKey: publicKey, data: data, error: error))
            }
        })
    }

    public func signE2EECertificate(certificate: String,
                                    options: NKRequestOptions = NKRequestOptions()) async -> (account: String, certificate: String?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            signE2EECertificate(certificate: certificate, options: options) { account, certificate, data, error in
                continuation.resume(returning: (account: account, certificate: certificate, data: data, error: error))
            }
        })
    }

    public func storeE2EEPrivateKey(privateKey: String,
                                    options: NKRequestOptions = NKRequestOptions()) async -> (account: String, privateKey: String?, data: Data?, error: NKError) {

        await withUnsafeContinuation({ continuation in
            storeE2EEPrivateKey(privateKey: privateKey, options: options) { account, privateKey, data, error in
                continuation.resume(returning: (account: account, privateKey: privateKey, data: data, error: error))
            }
        })
    }

    public func deleteE2EECertificate(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {

        await withUnsafeContinuation({ continuation in
            deleteE2EECertificate(options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }

    public func deleteE2EEPrivateKey(options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {

        await withUnsafeContinuation({ continuation in
            deleteE2EEPrivateKey(options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }
}
