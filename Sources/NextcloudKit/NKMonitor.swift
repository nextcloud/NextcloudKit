// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

final class NKMonitor: EventMonitor, Sendable {
    let nkCommonInstance: NKCommon
    let queue = DispatchQueue(label: "com.nextcloudkit.monitor")

    init(nkCommonInstance: NKCommon) {
        self.nkCommonInstance = nkCommonInstance
    }

    func requestDidResume(_ request: Request) {
        switch NKLogFileManager.shared.logLevel {
        case .normal:
            // General-purpose log: full Request description
            nkLog(info: "Request started: \(request)")
        case .verbose:
            // Full dump: headers + body
            let headers = request.request?.allHTTPHeaderFields?.description ?? "None"
            let body = request.request?.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "None"
            nkLog(debug: "Request started: \(request)")
            nkLog(debug: "Headers: \(headers)")
            nkLog(debug: "Body: \(body)")
        default:
            break
        }
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) {
        nkCommonInstance.delegate?.request(request, didParseResponse: response)

        if let statusCode = response.response?.statusCode,
           let headerCheckInterceptor = request.request?.allHTTPHeaderFields?[nkCommonInstance.headerCheckInterceptor],
           headerCheckInterceptor.lowercased() == "true",
           let account = request.request?.allHTTPHeaderFields?[nkCommonInstance.headerAccount] {
            nkCommonInstance.appendServerErrorAccount(account, errorCode: statusCode)
        }
        guard let date = self.nkCommonInstance.convertDate(Date(), format: "yyyy-MM-dd' 'HH:mm:ss") else {
            return
        }
        let responseResultString = String("\(response.result)")
        let responseDebugDescription = String("\(response.debugDescription)")
        let responseAllHeaderFields = String("\(String(describing: response.response?.allHeaderFields))")

        switch NKLogFileManager.shared.logLevel {
        case .normal:
            if let request = response.request {
                let requestString = "\(request)"
                nkLog(info: "Network response request: " + requestString + ", result: " + responseResultString)
            } else {
                nkLog(info: "Network response result: " + responseResultString)
            }
        case .compact:
            if let method = request.request?.httpMethod,
               let url = request.request?.url?.absoluteString,
               let code = response.response?.statusCode {
                // Determine response status string
                let responseStatus = (200..<300).contains(code) ? "RESPONSE: SUCCESS" : "RESPONSE: ERROR"

                // Extract error code if any
                let errorCode = response.error.map { " (\($0._code))" } ?? ""

                nkLog(network: "\(code) \(method) \(url) \(responseStatus)\(errorCode)")
            }
        case .verbose:
            nkLog(debug: "Network response result: \(date) " + responseDebugDescription)
            nkLog(debug: "Network response all headers: \(date) " + responseAllHeaderFields)
        default:
            break
        }
    }
}
