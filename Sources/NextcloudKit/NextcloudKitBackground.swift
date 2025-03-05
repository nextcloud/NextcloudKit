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

    public func download(serverUrlFileName: Any,
                         fileNameLocalPath: String,
                         taskDescription: String? = nil,
                         account: String) -> (URLSessionDownloadTask?, error: NKError?) {
        var url: URL?
        let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)

        if serverUrlFileName is URL {
            url = serverUrlFileName as? URL
        } else if serverUrlFileName is String || serverUrlFileName is NSString {
            url = (serverUrlFileName as? String)?.encodedToUrl as? URL
        }

        if let unauthorizedArray = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String],
           unauthorizedArray.contains(account) {
            return (nil, .unauthorizedError)
        } else if let tosArray = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String],
                  tosArray.contains(account) {
            return (nil, .forbiddenError)
        }

        guard let nkSession = nkCommonInstance.getSession(account: account),
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

        let task = nkSession.sessionDownloadBackground.downloadTask(with: request)
        task.taskDescription = taskDescription
        task.resume()
        self.nkCommonInstance.writeLog("Network start download file: \(serverUrlFileName)")

        return (task, .success)
    }

    // MARK: - Upload

    public func upload(serverUrlFileName: Any,
                       fileNameLocalPath: String,
                       dateCreationFile: Date?,
                       dateModificationFile: Date?,
                       taskDescription: String? = nil,
                       overwrite: Bool = false,
                       account: String,
                       sessionIdentifier: String) -> (URLSessionUploadTask?, error: NKError?) {
        var url: URL?
        var uploadSession: URLSession?
        let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)

        if serverUrlFileName is URL {
            url = serverUrlFileName as? URL
        } else if serverUrlFileName is String || serverUrlFileName is NSString {
            url = (serverUrlFileName as? String)?.encodedToUrl as? URL
        }

        if let unauthorizedArray = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String],
           unauthorizedArray.contains(account) {
            return (nil, .unauthorizedError)
        } else if let tosArray = groupDefaults?.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String],
                  tosArray.contains(account) {
            return (nil, .forbiddenError)
        }

        guard let nkSession = nkCommonInstance.getSession(account: account),
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
        task?.resume()
        self.nkCommonInstance.writeLog("Network start upload file: \(serverUrlFileName)")

        return (task, .success)
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
            if let dateString = self.nkCommonInstance.findHeader("date", allHeaderFields: header) {
                date = self.nkCommonInstance.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz")
            }
            if let dateString = header["Last-Modified"] as? String {
                dateLastModified = self.nkCommonInstance.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz")
            }
            length = header["Content-Length"] as? Int64 ?? 0
        }

        if task is URLSessionDownloadTask {
            self.nkCommonInstance.delegate?.downloadComplete(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, task: task, error: nkError)
        } else if task is URLSessionUploadTask {
            self.nkCommonInstance.delegate?.uploadComplete(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size: task.countOfBytesExpectedToSend, task: task, error: nkError)
        }

        if nkError.errorCode == 0 {
            self.nkCommonInstance.writeLog("Network completed file: \(serverUrl)/\(fileName)")
        } else {
            self.nkCommonInstance.writeLog("Network completed file: \(serverUrl)/\(fileName) with error code \(nkError.errorCode) and error description " + nkError.errorDescription)
        }
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if self.nkCommonInstance.delegate == nil {
            self.nkCommonInstance.writeLog("[WARNING] URLAuthenticationChallenge, no delegate found, perform with default handling")
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        } else {
            self.nkCommonInstance.delegate?.authenticationChallenge(session, didReceive: challenge, completionHandler: { authChallengeDisposition, credential in
                if self.nkCommonInstance.levelLog > 1 {
                    self.nkCommonInstance.writeLog("[INFO AUTH] Challenge Disposition: \(authChallengeDisposition.rawValue)")
                }
                completionHandler(authChallengeDisposition, credential)
            })
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        self.nkCommonInstance.delegate?.urlSessionDidFinishEvents(forBackgroundURLSession: session)
    }
}
