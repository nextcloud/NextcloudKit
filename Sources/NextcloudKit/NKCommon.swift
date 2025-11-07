// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

public enum NKTypeReachability: Int, Sendable {
    case unknown = 0
    case notReachable = 1
    case reachableEthernetOrWiFi = 2
    case reachableCellular = 3
}

public protocol NextcloudKitDelegate: AnyObject, Sendable {
    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)

    func networkReachabilityObserver(_ typeReachability: NKTypeReachability)

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>)

    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)

    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError)
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError)
}

public extension NextcloudKitDelegate {
    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) { }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) { }

    func networkReachabilityObserver(_ typeReachability: NKTypeReachability) { }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) { }

    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) { }
    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) { }

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) { }

    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError) { }
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError) { }
}

public struct NKCommon: Sendable {
    public var nksessions = SynchronizedNKSessionArray()
    public var delegate: NextcloudKitDelegate?
    public var groupIdentifier: String?
    public let typeIdentifiers: NKTypeIdentifiers = .shared

    // Roor fileName folder
    public let rootFileName: String = "__NC_ROOT__"

    // Foreground
    public let identifierSessionDownload: String = "com.nextcloud.nextcloudkit.session.download"
    public let identifierSessionUpload: String = "com.nextcloud.nextcloudkit.session.upload"
    // Background
    public let identifierSessionDownloadBackground: String = "com.nextcloud.session.downloadbackground"
    public let identifierSessionDownloadBackgroundExt: String = "com.nextcloud.session.downloadextension"

    public let identifierSessionUploadBackground: String = "com.nextcloud.session.uploadbackground"
    public let identifierSessionUploadBackgroundWWan: String = "com.nextcloud.session.uploadbackgroundWWan"
    public let identifierSessionUploadBackgroundExt: String = "com.nextcloud.session.uploadextension"

    public let rootQueue = DispatchQueue(label: "com.nextcloud.session.rootQueue")
    public let requestQueue = DispatchQueue(label: "com.nextcloud.session.requestQueue")
    public let serializationQueue = DispatchQueue(label: "com.nextcloud.session.serializationQueue")
    public let backgroundQueue = DispatchQueue(label: "com.nextcloud.nextcloudkit.backgroundqueue", qos: .background, attributes: .concurrent)
    private let logQueue = DispatchQueue(label: "com.nextcloud.nextcloudkit.queuelog", attributes: .concurrent )

    public let notificationCenterChunkedFileStop = NSNotification.Name(rawValue: "NextcloudKit.chunkedFile.stop")

    public let headerAccount = "X-NC-Account"
    public let headerCheckInterceptor = "X-NC-CheckInterceptor"
    public let groupDefaultsUnauthorized = "Unauthorized"
    public let groupDefaultsUnavailable = "Unavailable"
    public let groupDefaultsToS = "ToS"

    // MARK: - Init

    init() { }

    // MARK: - Chunked File

    public func chunkedFile(inputDirectory: String,
                            outputDirectory: String,
                            fileName: String,
                            chunkSize: Int,
                            filesChunk: [(fileName: String, size: Int64)],
                            numChunks: @escaping (_ num: Int) -> Void = { _ in },
                            counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                            completion: @escaping (_ filesChunk: [(fileName: String, size: Int64)], _ error: Error?) -> Void = { _, _ in }) {
        // Return existing chunks immediately
        if !filesChunk.isEmpty {
            numChunks(max(0, filesChunk.count - 1))
            return completion(filesChunk, nil)
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        var reader: FileHandle?
        var writer: FileHandle?
        var chunkWrittenBytes = 0
        var counter = 1
        var incrementalSize: Int64 = 0
        var filesChunk: [(fileName: String, size: Int64)] = []
        var chunkSize = chunkSize
        let bufferSize = 1_000_000
        var stop = false

        // If max chunk count is > 10000 (max count), add + 100 MB to the chunk size to reduce the count. This is an edge case.
        let inputFilePath = inputDirectory + "/" + fileName
        let totalSize = getFileSize(filePath: inputFilePath)
        var num: Int = Int(totalSize / Int64(chunkSize))

        if num > 10_000 {
            chunkSize += 100_000_000
            num = Int(totalSize / Int64(chunkSize))
        }
        numChunks(num)

        // Create output directory if needed
        if !fileManager.fileExists(atPath: outputDirectory, isDirectory: &isDirectory) {
            do {
                try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return completion([], NSError(domain: "chunkedFile", code: -2,userInfo: [NSLocalizedDescriptionKey: "Failed to create the output directory for file chunks."]))
            }
        }

        // Open input file
        do {
            reader = try .init(forReadingFrom: URL(fileURLWithPath: inputFilePath))
        } catch {
            return completion([], NSError(domain: "chunkedFile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open the input file for reading."]))
        }

        let tokenObserver = NotificationCenter.default.addObserver(forName: notificationCenterChunkedFileStop, object: nil, queue: nil) { _ in
            stop = true
        }

        defer {
            NotificationCenter.default.removeObserver(tokenObserver)

            try? writer?.close()
            try? reader?.close()
        }

        outerLoop: repeat {
            if stop {
                return completion([], NSError(domain: "chunkedFile", code: -5, userInfo: [NSLocalizedDescriptionKey: "Chunking was stopped by user request or system notification."]))
            }

            let result = autoreleasepool(invoking: { () -> Int in
                let remaining = chunkSize - chunkWrittenBytes
                guard let rawBuffer = reader?.readData(ofLength: min(bufferSize, remaining)) else {
                    return -1 // Error: read failed
                }

                if rawBuffer.isEmpty {
                    // Final flush of last chunk
                    if writer != nil {
                        writer?.closeFile()
                        writer = nil
                        counterChunk(counter)
                        debugPrint("[DEBUG] Final chunk closed: \(counter)")
                        counter += 1
                    }
                    return 0 // End of file
                }

                let safeBuffer = Data(rawBuffer)


                if writer == nil {
                    let fileNameChunk = String(counter)
                    let outputFileName = outputDirectory + "/" + fileNameChunk
                    fileManager.createFile(atPath: outputFileName, contents: nil, attributes: nil)
                    do {
                        writer = try FileHandle(forWritingTo: URL(fileURLWithPath: outputFileName))
                    } catch {
                        return -2 // Error: cannot create writer
                    }
                    filesChunk.append((fileName: fileNameChunk, size: 0))
                }

                // Check free disk space
                if let free = try? URL(fileURLWithPath: outputDirectory)
                    .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                    .volumeAvailableCapacityForImportantUsage,
                   free < Int64(safeBuffer.count * 2) {
                    return -3 // Not enough disk space
                }

                do {
                    try writer?.write(contentsOf: safeBuffer)
                    chunkWrittenBytes += safeBuffer.count
                    if chunkWrittenBytes >= chunkSize {
                        writer?.closeFile()
                        writer = nil
                        chunkWrittenBytes = 0
                        counterChunk(counter)
                        debugPrint("[DEBUG] Chunk completed: \(counter)")
                        counter += 1
                    }
                    return 1 // OK
                } catch {
                    return -4 // Write error
                }
            })

            switch result {
            case -1:
                return completion([], NSError(domain: "chunkedFile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read data from the input file."]))
            case -2:
                return completion([], NSError(domain: "chunkedFile", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to open the output chunk file for writing."]))
            case -3:
                return completion([], NSError(domain: "chunkedFile", code: -3, userInfo: [NSLocalizedDescriptionKey: "There is not enough available disk space to proceed."]))
            case -4:
                return completion([], NSError(domain: "chunkedFile", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to write data to chunk file."]))
            case 0:
                break outerLoop
            case 1:
                continue
            default:
                break
            }
        } while true

        // Update incremental chunk sizes
        for i in 0..<filesChunk.count {
            let path = outputDirectory + "/" + filesChunk[i].fileName
            let size = getFileSize(filePath: path)
            incrementalSize += size
            filesChunk[i].size = incrementalSize
        }

        completion(filesChunk, nil)
    }

    // MARK: - Server Error GroupDefaults

    public func appendServerErrorAccount(_ account: String, errorCode: Int) async {
        guard let groupDefaults = UserDefaults(suiteName: groupIdentifier) else {
            return
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)

        /// Unavailable
        if errorCode == 503 {
            var array = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable) as? [String] ?? []

            if !array.contains(account) {
                array.append(account)
                groupDefaults.set(array, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable)
            }
        /// Unauthorized
        } else if errorCode == 401 {
            var array = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String] ?? []

            if !array.contains(account) {
                array.append(account)
                groupDefaults.set(array, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized)
            }
        /// ToS
        } else if errorCode == 403, capabilities.termsOfService {
            var array = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String] ?? []

            if !array.contains(account) {
                array.append(account)
                groupDefaults.set(array, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS)
            }
        }
    }

    // MARK: - Common

    public func getSessionConfigurationIdentifier(_ identifier: String, account: String) -> String {
        return "\(identifier).\(account)"
    }

    public func getStandardHeaders(account: String,
                                   options: NKRequestOptions? = nil,
                                   contentType: String? = nil,
                                   accept: String? = nil) -> HTTPHeaders? {
        guard let session = nksessions.session(forAccount: account) else {
            return nil
        }
        var headers: HTTPHeaders = []

        headers.update(.authorization(username: session.user, password: session.password))
        headers.update(.userAgent(session.userAgent))
        if let customUserAgent = options?.customUserAgent {
            headers.update(.userAgent(customUserAgent))
        }
        if let contentType {
            headers.update(.contentType(contentType))
        }
        if let accept {
            headers.update(name: "Accept", value: accept)
        } else {
            headers.update(name: "Accept", value: "application/json")
        }
        headers.update(name: "OCS-APIRequest", value: "true")
        for (key, value) in options?.customHeader ?? [:] {
            headers.update(name: key, value: value)
        }
        headers.update(name: headerAccount, value: account)
        if let checkInterceptor = options?.checkInterceptor {
            headers.update(name: headerCheckInterceptor, value: checkInterceptor.description)
        }
        // Paginate
        if let options {
            if options.paginate {
                headers.update(name: "X-NC-Paginate", value: "true")
            }
            if let paginateCount = options.paginateCount {
                headers.update(name: "X-NC-Paginate-Count", value: "\(paginateCount)")
            }
            if let paginateOffset = options.paginateOffset {
                headers.update(name: "X-NC-Paginate-Offset", value: "\(paginateOffset)")
            }
            if let paginateToken = options.paginateToken {
                headers.update(name: "X-NC-Paginate-Token", value: paginateToken)
            }
        }
        return headers
    }

    public func createStandardUrl(serverUrl: String, endpoint: String) -> URLConvertible? {
        guard var serverUrl = serverUrl.urlEncoded else { return nil }

        if serverUrl.last != "/" { serverUrl = serverUrl + "/" }
        serverUrl = serverUrl + endpoint
        return serverUrl.asUrl
    }

    func findHeader(_ header: String, allHeaderFields: [AnyHashable: Any]?) -> String? {
        guard let allHeaderFields = allHeaderFields else { return nil }
        let keyValues = allHeaderFields.map { (String(describing: $0.key).lowercased(), String(describing: $0.value)) }

        if let headerValue = keyValues.filter({ $0.0 == header.lowercased() }).first {
            return headerValue.1
        }
        return nil
    }

    func getHostName(urlString: String) -> String? {
        if let url = URL(string: urlString) {
            guard let hostName = url.host else { return nil }
            guard let scheme = url.scheme else { return nil }
            if let port = url.port {
                return scheme + "://" + hostName + ":" + String(port)
            }
            return scheme + "://" + hostName
        }
        return nil
    }

    func getHostNameComponent(urlString: String) -> String? {
        if let url = URL(string: urlString) {
            let components = url.pathComponents
            return components.joined(separator: "")
        }
        return nil
    }

    func getFileSize(filePath: String) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.size] as? Int64 ?? 0
        } catch {
            debugPrint(error)
        }
        return 0
    }

    public func returnPathfromServerUrl(_ serverUrl: String, urlBase: String, userId: String) -> String {
        let home = urlBase + "/remote.php/dav/files/" + userId
        return serverUrl.replacingOccurrences(of: home, with: "")
    }

    public func getSessionErrorFromAFError(_ afError: AFError?) -> NSError? {
        if let afError = afError?.asAFError {
            switch afError {
            case .sessionTaskFailed(let sessionError):
                return sessionError as NSError
            default: break
            }
        }
        return nil
    }
 }
