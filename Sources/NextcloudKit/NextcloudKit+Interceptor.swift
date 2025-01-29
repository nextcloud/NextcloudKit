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

    private var isSessionBlocked = false
    private var retryCount = 0
    private let maxRetryAttempts = 1 // Numero massimo di retry per errore 401

    // MARK: - ADAPT
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        if isSessionBlocked {
            let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
            completion(.failure(error))
            return
        }

        var modifiedRequest = urlRequest
        modifiedRequest.setValue("Bearer myToken", forHTTPHeaderField: "Authorization")
        completion(.success(modifiedRequest))
    }

    // MARK: - RETRY
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let response = request.task?.response as? HTTPURLResponse else {
            completion(.doNotRetry)
            return
        }

        if response.statusCode == 401 {
            if retryCount < maxRetryAttempts {
                retryCount += 1
                print("Retrying request (attempt \(retryCount))...")
                completion(.retryWithDelay(1.0))
            } else {
                print("Sessione bloccata dopo 401!")
                isSessionBlocked = true
                completion(.doNotRetry)
            }
        } else {
            completion(.doNotRetry)
        }
    }

    //
    func resetSession() {
        isSessionBlocked = false
        retryCount = 0
    }
}
