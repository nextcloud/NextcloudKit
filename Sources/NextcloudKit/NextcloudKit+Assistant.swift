//
//  NextcloudKit+Assistant.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 26/03/24.
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
import Alamofire
import SwiftyJSON

extension NextcloudKit {
    public func getTextProcessingTaskTypes(options: NKRequestOptions = NKRequestOptions(),
                                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                           completion: @escaping (_ account: String, _ types: [NKTextProcessingTaskTypes]?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase

        let endpoint = "ocs/v2.php/textprocessing/tasktypes"

        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        sessionManager.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]["types"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NKTextProcessingTaskTypes.factory(data: data)
                    options.queue.async { completion(account, results, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            }
        }
    }
}

public class NKTextProcessingTaskTypes {
    var id: String?
    var name: String?
    var description: String?

    init?(json: JSON) {
        self.id = json["id"].string
        self.name = json["name"].string
        self.description = json["description"].string
    }

    static func factory(data: JSON) -> [NKTextProcessingTaskTypes]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NKTextProcessingTaskTypes.init)
    }
}
