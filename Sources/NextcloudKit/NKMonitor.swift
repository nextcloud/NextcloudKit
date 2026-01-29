// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

//  Description:
//
//  NKMonitor is an Alamofire EventMonitor implementation used to observe
//  the lifecycle of network requests and responses within the Nextcloud iOS client.
//
//  Its primary responsibilities are:
//
//  - Logging outgoing requests and incoming responses at different verbosity levels.
//  - Tracking server-side error codes per account for diagnostic and recovery purposes.
//  - Detecting potential account mismatches between the logical account assigned
//    to a request and the user encoded in the WebDAV request path.
//
//  Account Safety and Diagnostics:
//
//  In a multi-account environment, it is critical to ensure that each request
//  is executed using the correct account credentials.
//
//  To support this, NKMonitor:
//
//  - Extracts the logical account identifier from a custom internal HTTP header
//    attached to each request.
//  - On authentication failures (HTTP 401), compares the account identifier
//    against the username declared in the WebDAV path (e.g. /remote.php/dav/files/<user>).
//  - Logs an explicit error when a mismatch is detected, providing deterministic
//    evidence of a request executed with inconsistent account context.
//
//  This mechanism allows distinguishing between:
//  - Legitimate authentication failures for the correct account.
//  - Requests accidentally executed using credentials belonging to a different account.
//
//  Threading Model:
//
//  - All logging operations are performed on a dedicated background DispatchQueue.
//  - The monitor does not assume any actor isolation and is intentionally not Sendable.
//  - Consumers of delegate callbacks are responsible for ensuring thread safety.
//
//  Security Notes:
//
//  - Authorization headers are never inspected or decoded.
//  - Only application-internal account identifiers are logged.
//  - No credentials or sensitive authentication material are exposed.
//
//  NKMonitor is intended as an observational and diagnostic component and does not
//  modify request execution or response handling.
//

final class NKMonitor: EventMonitor {
    internal let nkCommonInstance: NKCommon
    internal let queue = DispatchQueue(label: "com.nextcloud.NKMonitor", qos: .utility)

    init(nkCommonInstance: NKCommon) {
        self.nkCommonInstance = nkCommonInstance
    }

    func requestDidResume(_ request: Request) {
        guard let urlRequest = request.request else {
            // URLRequest not created yet → skip logging
            return
        }
        let account = urlRequest.allHTTPHeaderFields?[self.nkCommonInstance.headerAccount] ?? "unknown"

        queue.async {
            switch NKLogFileManager.shared.logLevel {
            case .normal:
                // General-purpose log: full Request description
                nkLog(info: "User: \(account) - Request started: \(request)")
            case .verbose:
                // Full dump: headers + body
                let headers = urlRequest.allHTTPHeaderFields?.description ?? "None"
                let body = urlRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "None"

                nkLog(debug: "User: \(account)")
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
        let account = request.request?.allHTTPHeaderFields?[self.nkCommonInstance.headerAccount] ?? "unknown"

        // Check for header and account error code tracking
        if let statusCode = response.response?.statusCode,
           let headerCheckInterceptor = request.request?.allHTTPHeaderFields?[nkCommonInstance.headerCheckInterceptor],
           headerCheckInterceptor.lowercased() == "true",
           let account = request.request?.allHTTPHeaderFields?[nkCommonInstance.headerAccount] {
            Task {
                await nkCommonInstance.appendServerErrorAccount(account, errorCode: statusCode)
            }
        }

        // Check 401
        if response.response?.statusCode == 401 {
            let pathUser = request.request?.url?
                .path
                .components(separatedBy: "/files/")
                .dropFirst()
                .first

            if let pathUser, pathUser != account {
                nkLog(error: "ACCOUNT MISMATCH host=\(request.request?.url?.host ?? "-") pathUser=\(pathUser) headerUser=\(account)")
            }
        }

        queue.async {
            switch NKLogFileManager.shared.logLevel {
            case .normal:
                let resultString = String(describing: response.result)
                if let request = response.request {
                    nkLog(info: "User: \(account) - Network response request: \(request), result: \(resultString)")
                } else {
                    nkLog(info: "User: \(account) - Network response result: \(resultString)")
                }

            case .compact:
                if let method = request.request?.httpMethod,
                   let url = request.request?.url?.absoluteString,
                   let code = response.response?.statusCode {

                    let responseStatus = (200..<300).contains(code) ? "Response: SUCCESS" : "Response: ERROR"
                    nkLog(network: "User: \(account) Code: \(code) Method: \(method) Url: \(url) - \(responseStatus)")
                }

            case .verbose:
                let debugDesc = String(describing: response)
                let headerFields = String(describing: response.response?.allHeaderFields ?? [:])
                let date = Date().formatted(using: "yyyy-MM-dd' 'HH:mm:ss")

                nkLog(debug: "User: \(account)")
                nkLog(debug: "Network response result: \(date) " + debugDesc)
                nkLog(debug: "Network response all headers: \(date) " + headerFields)

            default:
                break
            }
        }
    }
}
