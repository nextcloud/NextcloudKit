// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 MarinoFaggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

#if os(macOS)
import Foundation
#else
import UIKit
#endif
import Alamofire
import SwiftyJSON

final class NextcloudKitSessionDelegate: SessionDelegate, @unchecked Sendable {
    public let nkCommonInstance: NKCommon?

    public init(fileManager: FileManager = .default, nkCommonInstance: NKCommon? = nil) {
        self.nkCommonInstance = nkCommonInstance
        super.init(fileManager: fileManager)
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let nkCommon = self.nkCommonInstance,
           let delegate = nkCommon.delegate {
            delegate.authenticationChallenge(session, didReceive: challenge) { authChallengeDisposition, credential in
                completionHandler(authChallengeDisposition, credential)
            }
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
}
