//
//  NextcloudKit+Dashboard.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 31/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
import Alamofire
import SwiftyJSON

extension NextcloudKit {

    public func getDashboard(filter: [String]? = nil,
                             options: NKRequestOptions = NKRequestOptions(),
                             request: @escaping (DataRequest?) -> Void,
                             completion: @escaping (_ account: String, _ dashboardResults: [NCCDashboardResult]?, _ json: JSON?, _ error: NKError) -> Void) {

        let account = NKCommon.shared.account

        var url: URLConvertible?

        if let endpoint = options.endpoint {
            url = URL(string: endpoint)
        } else {
            let endpoint = "/ocs/v2.php/apps/dashboard/api/v1/widget-items"
            url = NKCommon.shared.createStandardUrl(serverUrl: NKCommon.shared.urlBase, endpoint: endpoint)
        }

        guard let url = url else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options)

        let dashboardRequest = sessionManager.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)

            switch response.result {
            case .success(let json):
                let json = JSON(json)
                let data = json["ocs"]["data"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let dashboardResults = NCCDashboardResult.factory(data: data)
                    options.queue.async { completion(account, dashboardResults, data, .success) }
                } else {
                    options.queue.async { completion(account, nil, nil, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, nil, nil, error) }
            }
        }
        options.queue.async { request(dashboardRequest) }
    }
}
