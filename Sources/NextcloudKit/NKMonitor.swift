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

        if level >= .trace {
            nkLog(info: "Request started: \(request)")
        }

        if level == .verbose {
            let headers = request.request?.allHTTPHeaderFields?.description ?? "None"
            let body = request.request?.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "None"

            nkLog(debug: "Headers: \(headers)")
            nkLog(debug: "Body: \(body)")
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

        let level = NKLogFileManager.shared.minLevel

        if level >= .trace {
            if case let .failure(error) = response.result {
                nkLog(info: "Response failed: \(error.localizedDescription)")
            } else {
                nkLog(info: "Response succeeded.")
            }
        }

        if level >= .normal {
            let resultStr = String(describing: response.result)

            if let request = response.request {
                nkLog(info: "Full response from \(request): \(resultStr)")
            } else {
                nkLog(info: "Response result: \(resultStr)")
            }
        }

        if level == .verbose {
            let headers = String(describing: response.response?.allHeaderFields)
            let debugDescription = response.debugDescription
            nkLog(debug: "Debug info: \(debugDescription)")
            nkLog(debug: "Headers: \(headers)")
        }
    }
}
