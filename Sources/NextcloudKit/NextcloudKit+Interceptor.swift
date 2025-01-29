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
    public let nkCommonInstance = NKCommon()

    // MARK: - ADAPT (Prima della richiesta)
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let groupDefaults = UserDefaults(suiteName: nkCommonInstance.groupIdentifier)
        var modifiedRequest = urlRequest

        if let account = urlRequest.value(forHTTPHeaderField: "X-NC-Account") {
            
        }

        completion(.success(modifiedRequest))

        // Aggiungi l'header di autorizzazione
        modifiedRequest.setValue("Bearer myToken", forHTTPHeaderField: "Authorization")

        print("Richiesta modificata: \(modifiedRequest)")
        completion(.success(modifiedRequest))
    }
}
