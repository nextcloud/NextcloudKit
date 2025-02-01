// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

final class NKMonitor: EventMonitor {
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
}
