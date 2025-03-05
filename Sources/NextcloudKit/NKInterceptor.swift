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
        //
        // Detect if exists in the groupDefaults Unauthorized array the account
        //
        if let url: String = urlRequest.url?.absoluteString,
           self.nkCommonInstance.levelLog > 0 {
            debugPrint("[DEBUG] Interceptor request url: " + url)
        }

        if let checkUnauthorized = urlRequest.value(forHTTPHeaderField: nkCommonInstance.headerCheckUnauthorized),
           checkUnauthorized == "false" {
            return completion(.success(urlRequest))
        } else if let account = urlRequest.value(forHTTPHeaderField: nkCommonInstance.headerAccount),
                  let groupDefaults = UserDefaults(suiteName: nkCommonInstance.groupIdentifier),
                  let unauthorizedArray = groupDefaults.array(forKey: nkCommonInstance.groupDefaultsUnauthorized) as? [String],
                  unauthorizedArray.contains(account) {
            self.nkCommonInstance.writeLog("[DEBUG] Unauthorized for account: \(account)")
            let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
            return completion(.failure(error))
        }

        completion(.success(urlRequest))
    }
}
