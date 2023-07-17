//
//  NextcloudKit+Hovercard.swift
//  NextcloudKit
//
//  Created by Henrik Storch on 04/11/2021.
//  Copyright © 2021 Henrik Sorch. All rights reserved.
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

    @objc public func getHovercard(for userId: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   completion: @escaping (_ account: String, _ result: NKHovercard?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/hovercard/v1/\(userId)"

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint)
        else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]
                guard json["ocs"]["meta"]["statuscode"].int == 200,
                      let result = NKHovercard(jsonData: data)
                else {
                    let error = NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)
                    options.queue.async { completion(account, nil, jsonData, error) }
                    return
                }
                options.queue.async { completion(account, result, jsonData, .success) }
            }
        }
    }
}

@objc public class NKHovercard: NSObject {
    internal init?(jsonData: JSON) {
        guard let userId = jsonData["userId"].string,
              let displayName = jsonData["displayName"].string,
              let actions = jsonData["actions"].array?.compactMap(Action.init)
        else {
            return nil
        }
        self.userId = userId
        self.displayName = displayName
        self.actions = actions
    }

    @objc public class Action: NSObject {
        internal init?(jsonData: JSON) {
            guard let title = jsonData["title"].string,
                  let icon = jsonData["icon"].string,
                  let hyperlink = jsonData["hyperlink"].string,
                  let appId = jsonData["appId"].string
            else {
                return nil
            }
            self.title = title
            self.icon = icon
            self.hyperlink = hyperlink
            self.appId = appId
        }

        @objc public let title: String
        @objc public let icon: String
        @objc public let hyperlink: String
        @objc public var hyperlinkUrl: URL? { URL(string: hyperlink) }
        @objc public let appId: String
    }

    @objc public let userId, displayName: String
    @objc public let actions: [Action]
}
