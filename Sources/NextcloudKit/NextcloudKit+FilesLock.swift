//
//  NextcloudKit+FilesLock.swift
//  NextcloudKit
//
//  Created by Henrik Storch on 23.03.22.
//  Copyright © 2022 Henrik Sorch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import Alamofire
import SwiftyJSON

extension NextcloudKit {

    // available in NC >= 24
    @objc public func lockUnlockFile(serverUrlFileName: String,
                                     shouldLock: Bool,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     completion: @escaping (_ account: String, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account

        guard let url = serverUrlFileName.encodedToUrl
        else {
            return options.queue.async { completion(account, .urlError) }
        }

        let method = HTTPMethod(rawValue: shouldLock ? "LOCK" : "UNLOCK")

        var headers = self.nkCommonInstance.getStandardHeaders(options: options)
        headers.update(name: "X-User-Lock", value: "1")

        sessionManager.request(url, method: method, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).response(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }
}
