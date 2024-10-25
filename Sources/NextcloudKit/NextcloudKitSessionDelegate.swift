//
// SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation

#if os(macOS)
import Foundation
#else
import UIKit
#endif
import Alamofire
import SwiftyJSON

final class NextcloudKitSessionDelegate: SessionDelegate {
    public var nkCommonInstance: NKCommon? = nil

    override public init(fileManager: FileManager = .default) {
        super.init(fileManager: fileManager)
    }

    convenience init(nkCommonInstance: NKCommon?) {
        self.init()
        self.nkCommonInstance = nkCommonInstance
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let nkCommon = self.nkCommonInstance,
           let delegate = nkCommon.delegate {
            delegate.authenticationChallenge(session, didReceive: challenge) { authChallengeDisposition, credential in
                if nkCommon.levelLog > 1 {
                    nkCommon.writeLog("[INFO AUTH] Challenge Disposition: \(authChallengeDisposition.rawValue)")
                }
                completionHandler(authChallengeDisposition, credential)
            }
        } else {
            self.nkCommonInstance?.writeLog("[WARNING] URLAuthenticationChallenge, no delegate found, perform with default handling")
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
}
