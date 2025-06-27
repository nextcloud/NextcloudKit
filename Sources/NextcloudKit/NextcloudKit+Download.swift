// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    // Downloads a remote file and stores it at a local path for the specified Nextcloud account.
    // It provides detailed progress, headers, and metadata such as ETag, last modified date, and content length.
    //
    // Parameters:
    // - serverUrlFileName: A value representing the remote file URL or path (typically String or URL).
    // - fileNameLocalPath: The local filesystem path where the file should be saved.
    // - account: The Nextcloud account performing the download.
    // - options: Optional request options (default is empty).
    // - requestHandler: Closure to access the Alamofire `DownloadRequest` (for customization, inspection, etc.).
    // - taskHandler: Closure to access the underlying `URLSessionTask` (e.g. for progress or cancellation).
    // - progressHandler: Closure that receives periodic progress updates.
    // - completionHandler: Completion closure returning metadata: account, ETag, modification date, content length, headers, AFError, and NKError.
    func download(serverUrlFileName: Any,
                  fileNameLocalPath: String,
                  account: String,
                  options: NKRequestOptions = NKRequestOptions(),
                  requestHandler: @escaping (_ request: DownloadRequest) -> Void = { _ in },
                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                  progressHandler: @escaping (_ progress: Progress) -> Void = { _ in },
                  completionHandler: @escaping (_ account: String, _ etag: String?, _ date: Date?, _ lenght: Int64, _ headers: [AnyHashable: Any]?, _ afError: AFError?, _ nKError: NKError) -> Void) {
        var convertible: URLConvertible?
        if serverUrlFileName is URL {
            convertible = serverUrlFileName as? URLConvertible
        } else if serverUrlFileName is String || serverUrlFileName is NSString {
            convertible = (serverUrlFileName as? String)?.encodedToUrl
        }
        guard let url = convertible,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completionHandler(account, nil, nil, 0, nil, nil, .urlError) }
        }
        var destination: Alamofire.DownloadRequest.Destination?
        let fileNamePathLocalDestinationURL = NSURL.fileURL(withPath: fileNameLocalPath)
        let destinationFile: DownloadRequest.Destination = { _, _ in
            return (fileNamePathLocalDestinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        destination = destinationFile

        let request = nkSession.sessionData.download(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance), to: destination).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            options.queue.async { taskHandler(task) }
        } .downloadProgress { progress in
            options.queue.async { progressHandler(progress) }
        } .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let resultError = NKError(error: error, afResponse: response, responseData: nil)
                options.queue.async { completionHandler(account, nil, nil, 0, response.response?.allHeaderFields, error, resultError) }
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
                if let dateRaw = self.nkCommonInstance.findHeader("Date", allHeaderFields: response.response?.allHeaderFields) {
                    date = dateRaw.parsedDate(using: "yyyy-MM-dd HH:mm:ss")
                }

                options.queue.async { completionHandler(account, etag, date, length, response.response?.allHeaderFields, nil, .success) }
            }
        }

        options.queue.async { requestHandler(request) }
    }

    /// Asynchronously downloads a file and returns detailed download metadata.
    /// - Parameters:
    ///   - serverUrlFileName: The remote file path or URL (typically String or URL).
    ///   - fileNameLocalPath: The local file path where the file will be saved.
    ///   - account: The account performing the download.
    ///   - options: Optional request options (default is empty).
    ///   - requestHandler: Closure to access the `DownloadRequest`.
    ///   - taskHandler: Closure to access the `URLSessionTask`.
    ///   - progressHandler: Closure to monitor download progress.
    /// - Returns: A tuple with account, ETag, modified date, file size, headers, AFError (if any), and NKError.
    func downloadAsync(serverUrlFileName: Any,
                       fileNameLocalPath: String,
                       account: String,
                       options: NKRequestOptions = NKRequestOptions(),
                       requestHandler: @escaping (_ request: DownloadRequest) -> Void = { _ in },
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                       progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) async -> (String, String?, Date?, Int64, [AnyHashable: Any]?, AFError?, NKError) {
        await withCheckedContinuation { continuation in
            download(serverUrlFileName: serverUrlFileName,
                     fileNameLocalPath: fileNameLocalPath,
                     account: account,
                     options: options,
                     requestHandler: requestHandler,
                     taskHandler: taskHandler,
                     progressHandler: progressHandler) { account, etag, date, length, headers, afError, nKError in
                continuation.resume(returning: (account, etag, date, length, headers, afError, nKError))
            }
        }
    }
}
