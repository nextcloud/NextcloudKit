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

    // MARK: - ADAPT (Prima della richiesta)
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // Modifica la richiesta prima che venga inviata
        var modifiedRequest = urlRequest

        // Aggiungi l'header di autorizzazione
        modifiedRequest.setValue("Bearer myToken", forHTTPHeaderField: "Authorization")

        print("Richiesta modificata: \(modifiedRequest)")
        completion(.success(modifiedRequest))
    }
}
