// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

class NKInterceptor: RequestInterceptor, @unchecked Sendable {
    static let shared = Interceptor()

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)

        //
        // Detect if exists in the groupDefaults Unauthorized array the account
        //
        if let account = urlRequest.value(forHTTPHeaderField: "X-NC-Account"),
           let unauthorizedArray = groupDefaults?.array(forKey: "Unauthorized") as? [String],
           unauthorizedArray.contains(account) {
            let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
            return completion(.failure(error))
        }

        completion(.success(urlRequest))
    }
}
