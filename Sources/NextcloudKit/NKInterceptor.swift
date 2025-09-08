// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

final class NKInterceptor: RequestInterceptor, Sendable {
    let nkCommonInstance: NKCommon

    init(nkCommonInstance: NKCommon) {
        self.nkCommonInstance = nkCommonInstance
    }

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // Log request URL in verbose mode
        if NKLogFileManager.shared.logLevel == .verbose,
           let url = urlRequest.url?.absoluteString {
            nkLog(debug: "Interceptor request url: \(url)")
        }

        // Skip check if explicitly disabled
        if let checkInterceptor = urlRequest.value(forHTTPHeaderField: nkCommonInstance.headerCheckInterceptor),
           checkInterceptor == "false" {
            return completion(.success(urlRequest))
        }

        // Check for special error states via group defaults
        if let account = urlRequest.value(forHTTPHeaderField: nkCommonInstance.headerAccount),
           let groupDefaults = UserDefaults(suiteName: nkCommonInstance.groupIdentifier) {

            if let array = groupDefaults.array(forKey: nkCommonInstance.groupDefaultsUnauthorized) as? [String],
               array.contains(account) {
                nkLog(tag: "AUTH", emoji: .error, message: "Unauthorized for account: \(account)")
                let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
                return completion(.failure(error))

            } else if let array = groupDefaults.array(forKey: nkCommonInstance.groupDefaultsUnavailable) as? [String],
                      array.contains(account) {
                nkLog(tag: "SERVICE", emoji: .error, message: "Unavailable for account: \(account)")
                let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 503))
                return completion(.failure(error))

            } else if let array = groupDefaults.array(forKey: nkCommonInstance.groupDefaultsToS) as? [String],
                      array.contains(account) {
                nkLog(tag: "TOS", emoji: .error, message: "Terms of service error for account: \(account)")
                let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 403))
                return completion(.failure(error))
            }
        }

        completion(.success(urlRequest))
    }
}
