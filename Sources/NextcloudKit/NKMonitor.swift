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
        let level = NKLogFileManager.shared.minLevel

        // Always log at .info or lower
        if level <= .info {
            log(info: "Network request started: \(request)")
        }

        // If verbose enough, log headers and body
        if level <= .debug {
            let headers = request.request?.allHTTPHeaderFields?.description ?? "None"
            let body = request.request?.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "None"

            log(debug: "Network request headers: \(headers)")
            log(debug: "Network request body: \(body)")
        }
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) {
        nkCommonInstance.delegate?.request(request, didParseResponse: response)

        //
        // Server Error GroupDefaults
        //
        if let statusCode = response.response?.statusCode,
           let headerCheckInterceptor = request.request?.allHTTPHeaderFields?[nkCommonInstance.headerCheckInterceptor],
           headerCheckInterceptor.lowercased() == "true",
           let account = request.request?.allHTTPHeaderFields?[nkCommonInstance.headerAccount] {
            nkCommonInstance.appendServerErrorAccount(account, errorCode: statusCode)
        }

        //
        // LOG
        //
        let logLevel = NKLogFileManager.shared.minLevel

        if logLevel <= .info {
            let resultStr = String(describing: response.result)

            if let request = response.request {
                log(info: "Network response request: \(request), result: \(resultStr)")
            } else {
                log(info: "Network response result: \(resultStr)")
            }
        }

        if logLevel <= .debug {
            let headers = String(describing: response.response?.allHeaderFields)
            let debugDescription = response.debugDescription
            log(debug: "Network response debug: \(debugDescription)")
            log(debug: "Network response headers: \(headers)")
        }
    }
}
