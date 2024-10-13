//
//  NextcloudKit+Groupfolders.swift
//  NextcloudKit
//
//  Created by Henrik Storch on 12/04/2023.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

public extension NextcloudKit {
    func getGroupfolders(account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ results: [NKGroupfolders]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "index.php/apps/groupfolders/folders?applicable=1"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]
                guard json["ocs"]["meta"]["statuscode"].int == 200 || json["ocs"]["meta"]["statuscode"].int == 100
                else {
                    let error = NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)
                    options.queue.async { completion(account, nil, response, error) }
                    return
                }
                var results = [NKGroupfolders]()
                for (_, subJson) in data {
                    if let result = NKGroupfolders(json: subJson) {
                        results.append(result)
                    }
                }
                options.queue.async { completion(account, results, response, .success) }
            }
        }
    }
}

public class NKGroupfolders: NSObject {
    public let id: Int
    public let mountPoint: String
    public let acl: Bool
    public let size: Int
    public let quota: Int
    public let manage: Data?
    public let groups: [String: Any]?

    init?(json: JSON) {
        guard let id = json["id"].int,
              let mountPoint = json["mount_point"].string,
              let acl = json["acl"].bool,
              let size = json["size"].int,
              let quota = json["quota"].int
        else { return nil }

        self.id = id
        self.mountPoint = mountPoint
        self.acl = acl
        self.size = size
        self.quota = quota
        do {
            let data = try json["manage"].rawData()
            self.manage = data
        } catch {
            self.manage = nil
        }
        self.groups = json["groups"].dictionaryObject
    }
}
