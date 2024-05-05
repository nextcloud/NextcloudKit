//
//  NextcloudKit+Livephoto.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 09/11/2023.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import Alamofire

extension NextcloudKit {

    public func setLivephoto(serverUrlfileNamePath: String,
                             livePhotoFile: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                             completion: @escaping (_ account: String, _ error: NKError) -> Void) {

        let account = self.nkCommonInstance.account

        guard let url = serverUrlfileNamePath.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }

        let method = HTTPMethod(rawValue: "PROPPATCH")
        let headers = self.nkCommonInstance.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "application/xml")

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let parameters = String(format: NKDataFileXML(nkCommonInstance: self.nkCommonInstance).requestBodyLivephoto, livePhotoFile)
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.response(queue: self.nkCommonInstance.backgroundQueue) { response in
            if self.nkCommonInstance.levelLog > 0 {
                debugPrint(response)
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, error) }
            case .success:
                options.queue.async { completion(account, .success) }
            }
        }
    }

    @available(iOS 13.0, *)
    public func setLivephoto(serverUrlfileNamePath: String,
                             livePhotoFile: String,
                             options: NKRequestOptions = NKRequestOptions()) async -> (account: String, error: NKError) {

        await withUnsafeContinuation({ continuation in
            setLivephoto(serverUrlfileNamePath: serverUrlfileNamePath, livePhotoFile: livePhotoFile, options: options) { account, error in
                continuation.resume(returning: (account: account, error: error))
            }
        })
    }
}
