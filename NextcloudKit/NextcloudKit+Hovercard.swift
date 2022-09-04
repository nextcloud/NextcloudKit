//
//  NextcloudKit+Hovercard.swift
//  NextcloudKit
//
//  Created by Henrik Storch on 04/11/2021.
//  Copyright © 2021 Henrik Sorch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

    @objc public func getHovercard(for userId: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ result: NKHovercard?, _ error: NKError) -> Void) {

        let endpoint = "ocs/v2.php/hovercard/v1/\(userId)"
        let account = NKCommon.shared.account

        guard let url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint)
        else {
            queue.async {
                completionHandler(account, nil, .urlError)
            }
            return
        }

        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, error) }
            case .success(let json):
                let json = JSON(json)
                let data = json["ocs"]["data"]
                guard json["ocs"]["meta"]["statuscode"].int == 200,
                      let result = NKHovercard(jsonData: data)
                else {
                    let error = NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)
                    queue.async { completionHandler(account, nil, error) }
                    return
                }
                queue.async {
                    completionHandler(account, result, .success)
                }
            }
        }
    }
}
