// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func getDashboardWidget(account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            request: @escaping (DataRequest?) -> Void = { _ in },
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ dashboardWidgets: [NCCDashboardWidget]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/dashboard/api/v1/widgets"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let dashboardRequest = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NCCDashboardWidget.factory(data: data)
                    options.queue.async { completion(account, results, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            }
        }
        options.queue.async { request(dashboardRequest) }
    }

    func getDashboardWidgetsApplication(_ items: String,
                                        account: String,
                                        options: NKRequestOptions = NKRequestOptions(),
                                        request: @escaping (DataRequest?) -> Void = { _ in },
                                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                        completion: @escaping (_ account: String, _ dashboardApplications: [NCCDashboardApplication]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/dashboard/api/v1/widget-items?widgets[]=\(items)"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let dashboardRequest = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
            switch response.result {
            case .success(let jsonData):
                let json = JSON(jsonData)
                let data = json["ocs"]["data"]
                let statusCode = json["ocs"]["meta"]["statuscode"].int ?? NKError.internalError
                if 200..<300 ~= statusCode {
                    let results = NCCDashboardApplication.factory(data: data)
                    options.queue.async { completion(account, results, response, .success) }
                } else {
                    options.queue.async { completion(account, nil, response, NKError(rootJson: json, fallbackStatusCode: response.response?.statusCode)) }
                }
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            }
        }
        options.queue.async { request(dashboardRequest) }
    }
}

public class NCCDashboardApplication: NSObject {

    public var application: String?
    public var items: [NCCDashboardItem]?

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

public class NCCDashboardItem: NSObject {
    public let title: String?
    public let subtitle: String?
    public let link: String?
    public let iconUrl: String?
    public let sinceId: Int

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

public class NCCDashboardWidget: NSObject {
    public var id, title: String
    public let order: Int
    public let iconClass, iconUrl, widgetUrl: String?
    public let itemIconsRound: Bool
    public let button: [NCCDashboardWidgetButton]?

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

public class NCCDashboardWidgetButton: NSObject {
    public let type, text, link: String

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
