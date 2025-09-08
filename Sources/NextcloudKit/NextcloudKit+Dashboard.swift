// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Retrieves the list of dashboard widgets available for the specified Nextcloud account.
    /// This typically calls the dashboard API endpoint and returns a list of `NCCDashboardWidget` items.
    ///
    /// Parameters:
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional request options such as custom headers or retry policy (default is empty).
    /// - request: A closure that receives the underlying Alamofire `DataRequest`, useful for inspection or mutation.
    /// - taskHandler: A closure to access the `URLSessionTask` for progress or cancellation control.
    /// - completion: Completion handler returning the account, list of widgets, the raw response, and any NKError.
    func getDashboardWidget(account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            request: @escaping (DataRequest?) -> Void = { _ in },
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ dashboardWidgets: [NCCDashboardWidget]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/dashboard/api/v1/widgets"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let dashboardRequest = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously fetches the dashboard widgets available for a specific account.
    /// - Parameters:
    ///   - account: The account from which to fetch the widgets.
    ///   - options: Optional configuration for the request.
    ///   - request: Optional handler to capture the `DataRequest`.
    ///   - taskHandler: Optional handler for the `URLSessionTask`.
    /// - Returns: A tuple with the account, list of widgets, raw response, and NKError.
    func getDashboardWidgetAsync(account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 request: @escaping (DataRequest?) -> Void = { _ in },
                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        dashboardWidgets: [NCCDashboardWidget]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getDashboardWidget(account: account,
                               options: options,
                               request: request,
                               taskHandler: taskHandler) { account, dashboardWidgets, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    dashboardWidgets: dashboardWidgets,
                    responseData: responseData,
                    error: error
                ))
            }
        }
    }

    /// Retrieves the list of dashboard application widgets for the specified account and item string.
    /// This is typically used to fetch available dashboard apps filtered by `items` (e.g., "weather,tasks").
    ///
    /// Parameters:
    /// - items: A comma-separated string representing widget types or categories to fetch.
    /// - account: The Nextcloud account performing the request.
    /// - options: Optional request options (default is empty).
    /// - request: A closure that receives the underlying Alamofire `DataRequest`, useful for inspection or mutation.
    /// - taskHandler: A closure to access the `URLSessionTask` for progress or cancellation.
    /// - completion: Completion handler returning the account, list of applications, response, and error.
    func getDashboardWidgetsApplication(_ items: String,
                                        account: String,
                                        options: NKRequestOptions = NKRequestOptions(),
                                        request: @escaping (DataRequest?) -> Void = { _ in },
                                        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                        completion: @escaping (_ account: String, _ dashboardApplications: [NCCDashboardApplication]?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/dashboard/api/v1/widget-items?widgets[]=\(items)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let dashboardRequest = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
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

    /// Asynchronously fetches dashboard widgets tied to specific applications.
    /// - Parameters:
    ///   - items: A comma-separated list of app IDs (e.g., "files,calendar").
    ///   - account: The account performing the request.
    ///   - options: Optional request configuration.
    ///   - request: Handler for the `DataRequest` (if needed).
    ///   - taskHandler: Handler for the underlying `URLSessionTask`.
    /// - Returns: A tuple with account, dashboard applications, response data, and NKError.
    func getDashboardWidgetsApplicationAsync(_ items: String,
                                             account: String,
                                             options: NKRequestOptions = NKRequestOptions(),
                                             request: @escaping (DataRequest?) -> Void = { _ in },
                                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (
        account: String,
        dashboardApplications: [NCCDashboardApplication]?,
        responseData: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            getDashboardWidgetsApplication(items,
                                           account: account,
                                           options: options,
                                           request: request,
                                           taskHandler: taskHandler) { account, dashboardApplications, responseData, error in
                continuation.resume(returning: (
                    account: account,
                    dashboardApplications: dashboardApplications,
                    responseData: responseData,
                    error: error
                ))
            }
        }
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
