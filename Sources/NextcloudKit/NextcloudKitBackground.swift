// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public final class NKBackground: NSObject, URLSessionTaskDelegate, URLSessionDelegate, URLSessionDownloadDelegate {
    let nkCommonInstance: NKCommon

    public init(nkCommonInstance: NKCommon) {
        self.nkCommonInstance = nkCommonInstance
        super.init()
    }

    // MARK: - Download

    /// Starts a download task for a file from the server to a local path.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The URL or URL string of the file to download.
    ///   - fileNameLocalPath: The local file path where the downloaded file will be saved.
    ///   - taskDescription: Optional description to set on the URLSession task.
    ///   - account: The Nextcloud account associated with the download.
    ///
    /// - Returns: A tuple containing:
    ///   - URLSessionDownloadTask?: The download task if created successfully.
    ///   - error: An `NKError` indicating success or failure in starting the download.
    public func download(serverUrlFileName: Any,
                         fileNameLocalPath: String,
                         taskDescription: String? = nil,
                         account: String,
                         automaticResume: Bool = true,
                         sessionIdentifier: String) -> (URLSessionDownloadTask?, error: NKError) {
        var url: URL?
        var downloadSession: URLSession?
        let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)

        /// Check if error is in groupDefaults
        if let array = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String],
           array.contains(account) {
            return (nil, .unauthorizedError)
        } else if let array = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable) as? [String],
                  array.contains(account) {
            return (nil, .unavailableError)
        } else if let array = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String],
                  array.contains(account) {
            return (nil, .forbiddenError)
        }

        if serverUrlFileName is URL {
            url = serverUrlFileName as? URL
        } else if serverUrlFileName is String || serverUrlFileName is NSString {
            url = (serverUrlFileName as? String)?.encodedToUrl as? URL
        }

        guard var nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let urlForRequest = url
        else {
            return (nil, .urlError)
        }
        var request = URLRequest(url: urlForRequest)
        let loginString = "\(nkSession.user):\(nkSession.password)"

        guard let loginData = loginString.data(using: String.Encoding.utf8)
        else {
            return (nil, .invalidData)
        }
        let base64LoginString = loginData.base64EncodedString()

        request.setValue(nkSession.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")

        if sessionIdentifier == nkCommonInstance.identifierSessionDownloadBackground {
            downloadSession = nkSession.sessionDownloadBackground
        } else if sessionIdentifier == nkCommonInstance.identifierSessionDownloadBackgroundExt {
            downloadSession = nkSession.sessionDownloadBackgroundExt
        }

        let task = downloadSession?.downloadTask(with: request)
        task?.taskDescription = taskDescription

        if automaticResume {
            task?.resume()
        }

        return (task, .success)
    }

    /// Asynchronously starts a download task for a file.
    ///
    /// - Parameters: Same as the synchronous version.
    ///
    /// - Returns: A tuple containing:
    ///   - downloadTask: The `URLSessionDownloadTask?` if successfully created.
    ///   - error: The `NKError` result.
    public func downloadAsync(serverUrlFileName: Any,
                              fileNameLocalPath: String,
                              taskDescription: String? = nil,
                              account: String,
                              automaticResume: Bool = true,
                              sessionIdentifier: String) async -> (
        downloadTask: URLSessionDownloadTask?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let (task, error) = download(serverUrlFileName: serverUrlFileName,
                                         fileNameLocalPath: fileNameLocalPath,
                                         taskDescription: taskDescription,
                                         account: account,
                                         automaticResume: automaticResume,
                                         sessionIdentifier: sessionIdentifier)
            continuation.resume(returning: (downloadTask: task, error: error))
        }
    }

    // MARK: - Upload

    /// Starts an upload task to send a local file to the server.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The server URL or URL string where the file will be uploaded.
    ///   - fileNameLocalPath: The local file path of the file to upload.
    ///   - dateCreationFile: Optional creation date metadata for the file.
    ///   - dateModificationFile: Optional modification date metadata for the file.
    ///   - taskDescription: Optional description to set on the URLSession task.
    ///   - overwrite: Boolean indicating whether to overwrite existing files on the server.
    ///   - account: The Nextcloud account associated with the upload.
    ///   - sessionIdentifier: A string identifier for the upload session.
    ///
    /// - Returns: A tuple containing:
    ///   - URLSessionUploadTask?: The upload task if created successfully.
    ///   - error: An `NKError` indicating success or failure in starting the upload.
    public func upload(serverUrlFileName: Any,
                       fileNameLocalPath: String,
                       dateCreationFile: Date?,
                       dateModificationFile: Date?,
                       taskDescription: String? = nil,
                       overwrite: Bool = false,
                       account: String,
                       automaticResume: Bool = true,
                       sessionIdentifier: String) -> (URLSessionUploadTask?, error: NKError) {
        var url: URL?
        var uploadSession: URLSession?
        let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)

        guard FileManager.default.fileExists(atPath: fileNameLocalPath) else {
            return (nil, .urlError)
        }

        /// Check if error is in groupDefaults
        if let array = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String],
           array.contains(account) {
            return (nil, .unauthorizedError)
        } else if let array = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable) as? [String],
                  array.contains(account) {
            return (nil, .unavailableError)
        } else if let array = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String],
                  array.contains(account) {
            return (nil, .forbiddenError)
        }

        if serverUrlFileName is URL {
            url = serverUrlFileName as? URL
        } else if serverUrlFileName is String || serverUrlFileName is NSString {
            url = (serverUrlFileName as? String)?.encodedToUrl as? URL
        }

        guard var nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let urlForRequest = url
        else {
            return (nil, .urlError)
        }

        var request = URLRequest(url: urlForRequest)
        let loginString = "\(nkSession.user):\(nkSession.password)"
        guard let loginData = loginString.data(using: String.Encoding.utf8) else {
            return (nil, .invalidData)
        }
        let base64LoginString = loginData.base64EncodedString()

        request.httpMethod = "PUT"
        request.setValue(nkSession.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        if overwrite {
            request.setValue("true", forHTTPHeaderField: "Overwrite")
        }
        // Epoch of linux do not permitted negativ value
        if let dateCreationFile, dateCreationFile.timeIntervalSince1970 > 0 {
            request.setValue("\(dateCreationFile.timeIntervalSince1970)", forHTTPHeaderField: "X-OC-CTime")
        }
        // Epoch of linux do not permitted negativ value
        if let dateModificationFile, dateModificationFile.timeIntervalSince1970 > 0 {
            request.setValue("\(dateModificationFile.timeIntervalSince1970)", forHTTPHeaderField: "X-OC-MTime")
        }

        if sessionIdentifier == nkCommonInstance.identifierSessionUploadBackground {
            uploadSession = nkSession.sessionUploadBackground
        } else if sessionIdentifier == nkCommonInstance.identifierSessionUploadBackgroundWWan {
            uploadSession = nkSession.sessionUploadBackgroundWWan
        } else if sessionIdentifier == nkCommonInstance.identifierSessionUploadBackgroundExt {
            uploadSession = nkSession.sessionUploadBackgroundExt
        }

        let task = uploadSession?.uploadTask(with: request, fromFile: URL(fileURLWithPath: fileNameLocalPath))
        task?.taskDescription = taskDescription

        if automaticResume {
            task?.resume()
        }

        return (task, .success)
    }

    /// Asynchronously starts an upload task to send a local file.
    ///
    /// - Parameters: Same as the synchronous version.
    ///
    /// - Returns: A tuple containing:
    ///   - uploadTask: The `URLSessionUploadTask?` if successfully created.
    ///   - error: The `NKError` result.
    public func uploadAsync(serverUrlFileName: Any,
                            fileNameLocalPath: String,
                            dateCreationFile: Date?,
                            dateModificationFile: Date?,
                            taskDescription: String? = nil,
                            overwrite: Bool = false,
                            account: String,
                            automaticResume: Bool = true,
                            sessionIdentifier: String) async -> (
        uploadTask: URLSessionUploadTask?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            let (task, error) = upload(serverUrlFileName: serverUrlFileName,
                                       fileNameLocalPath: fileNameLocalPath,
                                       dateCreationFile: dateCreationFile,
                                       dateModificationFile: dateModificationFile,
                                       taskDescription: taskDescription,
                                       overwrite: overwrite,
                                       account: account,
                                       automaticResume: automaticResume,
                                       sessionIdentifier: sessionIdentifier)
            continuation.resume(returning: (uploadTask: task, error: error))
        }
    }

    // MARK: - SessionDelegate

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown else { return }
        guard let url = downloadTask.currentRequest?.url?.absoluteString.removingPercentEncoding else { return }
        let fileName = (url as NSString).lastPathComponent
        let serverUrl = url.replacingOccurrences(of: "/" + fileName, with: "")
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)

        self.nkCommonInstance.delegate?.downloadProgress(progress, totalBytes: totalBytesWritten, totalBytesExpected: totalBytesExpectedToWrite, fileName: fileName, serverUrl: serverUrl, session: session, task: downloadTask)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.nkCommonInstance.delegate?.downloadingFinish(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend != NSURLSessionTransferSizeUnknown else { return }
        guard let url = task.currentRequest?.url?.absoluteString.removingPercentEncoding else { return }
        let fileName = (url as NSString).lastPathComponent
        let serverUrl = url.replacingOccurrences(of: "/" + fileName, with: "")
        let progress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)

        self.nkCommonInstance.delegate?.uploadProgress(progress, totalBytes: totalBytesSent, totalBytesExpected: totalBytesExpectedToSend, fileName: fileName, serverUrl: serverUrl, session: session, task: task)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        var fileName: String = "", serverUrl: String = "", etag: String?, ocId: String?, date: Date?, dateLastModified: Date?, length: Int64 = 0
        let url = task.currentRequest?.url?.absoluteString.removingPercentEncoding
        if let url {
            fileName = (url as NSString).lastPathComponent
            serverUrl = url.replacingOccurrences(of: "/" + fileName, with: "")
        }
        var nkError: NKError = .success

        if let response = (task.response as? HTTPURLResponse) {
            if response.statusCode >= 200 && response.statusCode < 300 {
                if let error = error {
                    nkError = NKError(error: error)
                }
            } else {
                nkError = NKError(httpResponse: response)
            }
        } else {
            if let error = error {
                nkError = NKError(error: error)
            }
        }

        if let header = (task.response as? HTTPURLResponse)?.allHeaderFields {
            if self.nkCommonInstance.findHeader("oc-fileid", allHeaderFields: header) != nil {
                ocId = self.nkCommonInstance.findHeader("oc-fileid", allHeaderFields: header)
            } else if self.nkCommonInstance.findHeader("fileid", allHeaderFields: header) != nil {
                ocId = self.nkCommonInstance.findHeader("fileid", allHeaderFields: header)
            }
            if self.nkCommonInstance.findHeader("oc-etag", allHeaderFields: header) != nil {
                etag = self.nkCommonInstance.findHeader("oc-etag", allHeaderFields: header)
            } else if self.nkCommonInstance.findHeader("etag", allHeaderFields: header) != nil {
                etag = self.nkCommonInstance.findHeader("etag", allHeaderFields: header)
            }
            if etag != nil { etag = etag?.replacingOccurrences(of: "\"", with: "") }
            if let dateRaw = self.nkCommonInstance.findHeader("date", allHeaderFields: header) {
                date = dateRaw.parsedDate(using: "EEE, dd MMM y HH:mm:ss zzz")
            }
            if let dateString = header["Last-Modified"] as? String {
                dateLastModified = dateString.parsedDate(using: "EEE, dd MMM y HH:mm:ss zzz")
            }
            length = header["Content-Length"] as? Int64 ?? 0
        }

        if task is URLSessionDownloadTask {
            self.nkCommonInstance.delegate?.downloadComplete(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, task: task, error: nkError)
        } else if task is URLSessionUploadTask {
            self.nkCommonInstance.delegate?.uploadComplete(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size: task.countOfBytesExpectedToSend, task: task, error: nkError)
        }
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if self.nkCommonInstance.delegate == nil {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        } else {
            self.nkCommonInstance.delegate?.authenticationChallenge(session, didReceive: challenge, completionHandler: { authChallengeDisposition, credential in
                completionHandler(authChallengeDisposition, credential)
            })
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        self.nkCommonInstance.delegate?.urlSessionDidFinishEvents(forBackgroundURLSession: session)
    }
}
