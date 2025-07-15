// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

final class NKMonitor: EventMonitor, Sendable {
    let nkCommonInstance: NKCommon
    let queue = DispatchQueue(label: "com.nextcloud.NKMonitor")

    init(nkCommonInstance: NKCommon) {
        self.nkCommonInstance = nkCommonInstance
    }

    func requestDidResume(_ request: Request) {
        DispatchQueue.global(qos: .utility).async {
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
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) {
        nkCommonInstance.delegate?.request(request, didParseResponse: response)

        // Check for header and account error code tracking
        if let statusCode = response.response?.statusCode,
           let headerCheckInterceptor = request.request?.allHTTPHeaderFields?[nkCommonInstance.headerCheckInterceptor],
           headerCheckInterceptor.lowercased() == "true",
           let account = request.request?.allHTTPHeaderFields?[nkCommonInstance.headerAccount] {
            Task {
                await nkCommonInstance.appendServerErrorAccount(account, errorCode: statusCode)
            }
        }

        DispatchQueue.global(qos: .utility).async {
            switch NKLogFileManager.shared.logLevel {
            case .normal:
                let resultString = String(describing: response.result)

                if let request = response.request {
                    nkLog(info: "Network response request: \(request), result: \(resultString)")
                } else {
                    nkLog(info: "Network response result: \(resultString)")
                }

            case .compact:
                if let method = request.request?.httpMethod,
                   let url = request.request?.url?.absoluteString,
                   let code = response.response?.statusCode {

                    let responseStatus = (200..<300).contains(code) ? "RESPONSE: SUCCESS" : "RESPONSE: ERROR"
                    nkLog(network: "\(code) \(method) \(url) \(responseStatus)")
                }

            case .verbose:
                let debugDesc = String(describing: response)
                let headerFields = String(describing: response.response?.allHeaderFields ?? [:])
                let date = Date().formatted(using: "yyyy-MM-dd' 'HH:mm:ss")

                nkLog(debug: "Network response result: \(date) " + debugDesc)
                nkLog(debug: "Network response all headers: \(date) " + headerFields)

            default:
                break
            }
        }
    }
}
