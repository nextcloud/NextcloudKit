//
//  NextcloudKitSessionDelegate.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 07/08/2024.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
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

#if os(macOS)
import Foundation
#else
import UIKit
#endif
import Alamofire
import SwiftyJSON

open class NextcloudKitSessionDelegate: SessionDelegate {
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