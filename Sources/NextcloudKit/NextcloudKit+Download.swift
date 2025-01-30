// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    func download(serverUrlFileName: Any,
                  fileNameLocalPath: String,
                  account: String,
                  options: NKRequestOptions = NKRequestOptions(),
                  requestHandler: @escaping (_ request: DownloadRequest) -> Void = { _ in },
                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                  progressHandler: @escaping (_ progress: Progress) -> Void = { _ in },
                  completionHandler: @escaping (_ account: String, _ etag: String?, _ date: Date?, _ lenght: Int64, _ responseData: AFDownloadResponse<URL?>?, _ afError: AFError?, _ nKError: NKError) -> Void) {
        var convertible: URLConvertible?
        if serverUrlFileName is URL {
            convertible = serverUrlFileName as? URLConvertible
        } else if serverUrlFileName is String || serverUrlFileName is NSString {
            convertible = (serverUrlFileName as? String)?.encodedToUrl
        }
        guard let url = convertible,
              let nkSession = nkCommonInstance.getSession(account: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completionHandler(account, nil, nil, 0, nil, nil, .urlError) }
        }
        var destination: Alamofire.DownloadRequest.Destination?
        let fileNamePathLocalDestinationURL = NSURL.fileURL(withPath: fileNameLocalPath)
        let destinationFile: DownloadRequest.Destination = { _, _ in
            return (fileNamePathLocalDestinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        destination = destinationFile

        let request = nkSession.sessionData.download(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: headers, interceptor: nkInterceptor, to: destination).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            options.queue.async { taskHandler(task) }
        } .downloadProgress { progress in
            options.queue.async { progressHandler(progress) }
        } .response(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let resultError = NKError(error: error, afResponse: response, responseData: nil)
                options.queue.async { completionHandler(account, nil, nil, 0, response, error, resultError) }
            case .success:
                var date: Date?
                var etag: String?
                var length: Int64 = 0

                if let result = response.response?.allHeaderFields["Content-Length"] as? String {
                    length = Int64(result) ?? 0
                }
                if self.nkCommonInstance.findHeader("oc-etag", allHeaderFields: response.response?.allHeaderFields) != nil {
                    etag = self.nkCommonInstance.findHeader("oc-etag", allHeaderFields: response.response?.allHeaderFields)
                } else if self.nkCommonInstance.findHeader("etag", allHeaderFields: response.response?.allHeaderFields) != nil {
                    etag = self.nkCommonInstance.findHeader("etag", allHeaderFields: response.response?.allHeaderFields)
                }
                if etag != nil {
                    etag = etag?.replacingOccurrences(of: "\"", with: "")
                }
                if let dateString = self.nkCommonInstance.findHeader("Date", allHeaderFields: response.response?.allHeaderFields) {
                    date = self.nkCommonInstance.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz")
                }

                options.queue.async { completionHandler(account, etag, date, length, response, nil, .success) }
            }
        }

        options.queue.async { requestHandler(request) }
    }
}
