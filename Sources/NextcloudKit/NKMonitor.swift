// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

final class NKMonitor: EventMonitor, Sendable {
    let nkCommonInstance: NKCommon

    init(nkCommonInstance: NKCommon) {
        self.nkCommonInstance = nkCommonInstance
    }

    func requestDidResume(_ request: Request) {
        if self.nkCommonInstance.levelLog > 0 {
            self.nkCommonInstance.writeLog("Network request started: \(request)")
            if self.nkCommonInstance.levelLog > 1 {
                let allHeaders = request.request.flatMap { $0.allHTTPHeaderFields.map { $0.description } } ?? "None"
                let body = request.request.flatMap { $0.httpBody.map { String(decoding: $0, as: UTF8.self) } } ?? "None"

                self.nkCommonInstance.writeLog("Network request headers: \(allHeaders)")
                self.nkCommonInstance.writeLog("Network request body: \(body)")
            }
        }
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) {
        self.nkCommonInstance.delegate?.request(request, didParseResponse: response)
        let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)

        //
        // Error 401, append the account in groupDefaults Unauthorized array
        //
        if let statusCode = response.response?.statusCode {
           if statusCode == 401,
              let headerValue = request.request?.allHTTPHeaderFields?["X-NC-CheckUnauthorized"],
              headerValue.lowercased() == "true",
              let account = request.request?.allHTTPHeaderFields?["X-NC-Account"] as? String,
              let session = nkCommonInstance.getSession(account: account) {
               let serverUrlFileName = session.urlBase + "/remote.php/dav/files/" + session.userId
               self.readFile(serverUrlFileName: serverUrlFileName, account: account) { account, error in
                   /*
                   var unauthorizedArray = groupDefaults?.array(forKey: "Unauthorized") as? [String] ?? []
                   if !unauthorizedArray.contains(account) {
                       unauthorizedArray.append(account)
                       groupDefaults?.set(unauthorizedArray, forKey: "Unauthorized")

                       self.nkCommonInstance.writeLog("Unauthorized set for account: \(account)")
                   }
                   */
               }
           } else if statusCode == 503 {
               print("503 Service Unavailable")
           }
        }

        //
        // LOG
        //
        guard let date = self.nkCommonInstance.convertDate(Date(), format: "yyyy-MM-dd' 'HH:mm:ss") else { return }
        let responseResultString = String("\(response.result)")
        let responseDebugDescription = String("\(response.debugDescription)")
        let responseAllHeaderFields = String("\(String(describing: response.response?.allHeaderFields))")

        if self.nkCommonInstance.levelLog > 0 {
            if self.nkCommonInstance.levelLog == 1 {
                if let request = response.request {
                    let requestString = "\(request)"
                    self.nkCommonInstance.writeLog("Network response request: " + requestString + ", result: " + responseResultString)
                } else {
                    self.nkCommonInstance.writeLog("Network response result: " + responseResultString)
                }
            } else {
                self.nkCommonInstance.writeLog("Network response result: \(date) " + responseDebugDescription)
                self.nkCommonInstance.writeLog("Network response all headers: \(date) " + responseAllHeaderFields)
            }
        }
    }

    func readFile(serverUrlFileName: String,
                  account: String,
                  options: NKRequestOptions = NKRequestOptions(),
                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                  completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        ///
        options.contentType = "application/xml"
        ///
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = serverUrlFileName.encodedToUrl,
              var headers = nkCommonInstance.getStandardHeaders(account: account, checkUnauthorized: true, options: options) else {
            return options.queue.async { completion(account, .urlError) }
        }

        let method = HTTPMethod(rawValue: "PROPFIND")
        headers.update(name: "Depth", value: "0")
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodyFile(createProperties: options.createProperties, removeProperties: options.removeProperties).data(using: .utf8)

        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor()).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }
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
