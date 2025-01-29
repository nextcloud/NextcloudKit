//
//  NextcloudKit+in.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 29/01/25.
//

import Foundation
import Alamofire

class Interceptor: RequestInterceptor {
    static let shared = Interceptor()

    let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var modifiedRequest = urlRequest

        // Detect if exists in the groupDefaults Unauthorized array the account
        //
        if let account = urlRequest.value(forHTTPHeaderField: "X-NC-Account"),
           let unauthorizedArray = groupDefaults?.array(forKey: "Unauthorized") as? [String],
           unauthorizedArray.contains(account) {
            let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
            return completion(.failure(error))
        }

        modifiedRequest.setValue(nil, forHTTPHeaderField: "X-NC-Account")
        completion(.success(modifiedRequest))
    }
}
