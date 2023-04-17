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

    public func getDashboardWidget(options: NKRequestOptions = NKRequestOptions(),
                                   request: @escaping (DataRequest?) -> Void = { _ in },
                                   completion: @escaping (_ account: String, _ dashboardWidgets: [NCCDashboardWidget]?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var url: URLConvertible?

        if let endpoint = options.endpoint {
            url = URL(string: endpoint)
        } else {
            let endpoint = "ocs/v2.php/apps/dashboard/api/v1/widgets"
            url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint)
        }

        guard let url = url else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        let dashboardRequest = sessionManager.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NCCDashboardWidget.factory(data: data)
                    options.queue.async { completion(account, results, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            }
        }
        options.queue.async { request(dashboardRequest) }
    }

    public func getDashboardWidgetsApplication(_ items: String,
                                               options: NKRequestOptions = NKRequestOptions(),
                                               request: @escaping (DataRequest?) -> Void = { _ in },
                                               completion: @escaping (_ account: String, _ dashboardApplications: [NCCDashboardApplication]?, _ data: Data?, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account
        let urlBase = self.nkCommonInstance.urlBase
        var url: URLConvertible?

        if let endpoint = options.endpoint {
            url = URL(string: endpoint)
        } else {
            let endpoint = "ocs/v2.php/apps/dashboard/api/v1/widget-items?widgets[]=\(items)"
            url = self.nkCommonInstance.createStandardUrl(serverUrl: urlBase, endpoint: endpoint)
        }

        guard let url = url else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let headers = self.nkCommonInstance.getStandardHeaders(options: options)

        let dashboardRequest = sessionManager.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: nil).validate(statusCode: 200..<300).responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            debugPrint(response)

            switch response.result {
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NCCDashboardApplication.factory(data: data)
                    options.queue.async { completion(account, results, jsonData, .success) }
                } else {
                    options.queue.async { completion(account, nil, jsonData, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, nil, error) }
            }
        }
        options.queue.async { request(dashboardRequest) }
    }
}

@objc public class NCCDashboardApplication: NSObject {

    @objc public var application: String?
    @objc public var items: [NCCDashboardItem]?

    init?(application: String, data: JSON) {
        self.application = application
        self.items = NCCDashboardItem.factory(data: data)
    }

    static func factory(data: JSON) -> [NCCDashboardApplication] {
        var results = [NCCDashboardApplication]()
        for (application, data): (String, JSON) in data {
            if let result = NCCDashboardApplication(application: application, data: data) {
                results.append(result)
            }
        }
        return results
    }
}

@objc public class NCCDashboardItem: NSObject {

    @objc public let title: String?
    @objc public let subtitle: String?
    @objc public let link: String?
    @objc public let iconUrl: String?
    @objc public let sinceId: Int

    init?(json: JSON) {
        self.title = json["title"].string
        self.subtitle = json["subtitle"].string
        self.link = json["link"].string
        self.iconUrl = json["iconUrl"].string
        self.sinceId = json["sinceId"].int ?? 0
    }

    static func factory(data: JSON) -> [NCCDashboardItem]? {
        guard let allResults = data.array else { return nil }
        return allResults.compactMap(NCCDashboardItem.init)
    }
}

@objc public class NCCDashboardWidget: NSObject {

    @objc public var id, title: String
    @objc public let order: Int
    @objc public let iconClass, iconUrl, widgetUrl: String?
    @objc public let itemIconsRound: Bool
    @objc public let button: [NCCDashboardWidgetButton]?

    init?(application: String, data: JSON) {
        guard let id = data["id"].string,
              let title = data["title"].string,
              let order = data["order"].int
        else { return nil }
        self.id = id
        self.title = title
        self.order = order
        self.iconClass = data["icon_class"].string
        self.iconUrl = data["icon_url"].string
        self.widgetUrl = data["widget_url"].string
        self.itemIconsRound = data["item_icons_round"].boolValue
        self.button = NCCDashboardWidgetButton.factory(data: data["buttons"])
    }

    static func factory(data: JSON) -> [NCCDashboardWidget] {
        var results = [NCCDashboardWidget]()
        for (application, data): (String, JSON) in data {
            if let result = NCCDashboardWidget(application: application, data: data) {
                results.append(result)
            }
        }
        return results
    }
}

@objc public class NCCDashboardWidgetButton: NSObject {

    @objc public let type, text, link: String

    init?(data: JSON) {
        guard let type = data["type"].string,
              let text = data["text"].string,
              let link = data["link"].string
        else { return nil }
        self.type = type
        self.text = text
        self.link = link
    }

    static func factory(data: JSON) -> [NCCDashboardWidgetButton]? {
        guard let allProvider = data.array else { return nil }
        return allProvider.compactMap(NCCDashboardWidgetButton.init)
    }
}
