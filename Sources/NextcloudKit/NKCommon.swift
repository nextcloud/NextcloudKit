// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2023 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

#if os(iOS)
import MobileCoreServices
#else
import CoreServices
#endif

public protocol NextcloudKitDelegate: AnyObject, Sendable {
    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)

    func networkReachabilityObserver(_ typeReachability: NKCommon.TypeReachability)

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

    func networkReachabilityObserver(_ typeReachability: NKCommon.TypeReachability) { }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) { }

    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) { }
    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask) { }

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) { }

    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError) { }
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError) { }
}

public struct NKCommon: Sendable {
    public var nksessions = ThreadSafeArray<NKSession>()
    public var delegate: NextcloudKitDelegate?
    public var groupIdentifier: String?

    // Foreground
    public let identifierSessionDownload: String = "com.nextcloud.nextcloudkit.session.download"
    public let identifierSessionUpload: String = "com.nextcloud.nextcloudkit.session.upload"
    // Background
    public let identifierSessionDownloadBackground: String = "com.nextcloud.session.downloadbackground"
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

    public enum TypeReachability: Int {
        case unknown = 0
        case notReachable = 1
        case reachableEthernetOrWiFi = 2
        case reachableCellular = 3
    }

    // MARK: - Init

    init() {

    }

    // MARK: - Chunked File

    public func chunkedFile(inputDirectory: String,
                            outputDirectory: String,
                            fileName: String,
                            chunkSize: Int,
                            filesChunk: [(fileName: String, size: Int64)],
                            numChunks: @escaping (_ num: Int) -> Void = { _ in },
                            counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                            completion: @escaping (_ filesChunk: [(fileName: String, size: Int64)]) -> Void = { _ in }) {
        // Check if filesChunk is empty
        if !filesChunk.isEmpty { return completion(filesChunk) }

        defer {
            NotificationCenter.default.removeObserver(self, name: notificationCenterChunkedFileStop, object: nil)
        }

        let fileManager: FileManager = .default
        var isDirectory: ObjCBool = false
        var reader: FileHandle?
        var writer: FileHandle?
        var chunk: Int = 0
        var counter: Int = 1
        var incrementalSize: Int64 = 0
        var filesChunk: [(fileName: String, size: Int64)] = []
        var chunkSize = chunkSize
        let bufferSize = 1000000
        var stop: Bool = false

        NotificationCenter.default.addObserver(forName: notificationCenterChunkedFileStop, object: nil, queue: nil) { _ in stop = true }

        // If max chunk count is > 10000 (max count), add + 100 MB to the chunk size to reduce the count. This is an edge case.
        var num: Int = Int(getFileSize(filePath: inputDirectory + "/" + fileName) / Int64(chunkSize))
        if num > 10000 {
            chunkSize = chunkSize + 100000000
        }
        num = Int(getFileSize(filePath: inputDirectory + "/" + fileName) / Int64(chunkSize))
        numChunks(num)

        if !fileManager.fileExists(atPath: outputDirectory, isDirectory: &isDirectory) {
            do {
                try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return completion([])
            }
        }

        do {
            reader = try .init(forReadingFrom: URL(fileURLWithPath: inputDirectory + "/" + fileName))
        } catch {
            return completion([])
        }

        repeat {
            if stop {
                return completion([])
            }
            if autoreleasepool(invoking: { () -> Int in
                if chunk >= chunkSize {
                    writer?.closeFile()
                    writer = nil
                    chunk = 0
                    counterChunk(counter)
                    debugPrint("[DEBUG] Counter: \(counter)")
                    counter += 1
                }

                let chunkRemaining: Int = chunkSize - chunk
                let buffer = reader?.readData(ofLength: min(bufferSize, chunkRemaining))

                if writer == nil {
                    let fileNameChunk = String(counter)
                    let outputFileName = outputDirectory + "/" + fileNameChunk
                    fileManager.createFile(atPath: outputFileName, contents: nil, attributes: nil)
                    do {
                        writer = try .init(forWritingTo: URL(fileURLWithPath: outputFileName))
                    } catch {
                        filesChunk = []
                        return 0
                    }
                    filesChunk.append((fileName: fileNameChunk, size: 0))
                }

                if let buffer = buffer {
                    writer?.write(buffer)
                    chunk = chunk + buffer.count
                    return buffer.count
                }
                filesChunk = []
                return 0
            }) == 0 { break }
        } while true

        writer?.closeFile()
        reader?.closeFile()

        counter = 0
        for fileChunk in filesChunk {
            let size = getFileSize(filePath: outputDirectory + "/" + fileChunk.fileName)
            incrementalSize = incrementalSize + size
            filesChunk[counter].size = incrementalSize
            counter += 1
        }
        return completion(filesChunk)
    }

    // MARK: - Server Error GroupDefaults

    public func appendServerErrorAccount(_ account: String, errorCode: Int) {
        guard let groupDefaults = UserDefaults(suiteName: groupIdentifier) else {
            return
        }
        let capabilities = NCCapabilities.shared.getCapabilitiesBlocking(for: account)

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

    public func getSession(account: String) -> NKSession? {
        var session: NKSession?
        nksessions.forEach { result in
            if result.account == account {
                session = result
            }
        }
        return session
    }

    public func getStandardHeaders(account: String, options: NKRequestOptions? = nil) -> HTTPHeaders? {
        guard let session = nksessions.filter({ $0.account == account }).first else { return nil}
        var headers: HTTPHeaders = []

        headers.update(.authorization(username: session.user, password: session.password))
        headers.update(.userAgent(session.userAgent))
        if let customUserAgent = options?.customUserAgent {
            headers.update(.userAgent(customUserAgent))
        }
        if let contentType = options?.contentType {
            headers.update(.contentType(contentType))
        } else {
            headers.update(.contentType("application/x-www-form-urlencoded"))
        }
        if options?.contentType != "application/xml" {
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

    public func createStandardUrl(serverUrl: String, endpoint: String, options: NKRequestOptions) -> URLConvertible? {
        if let endpoint = options.endpoint {
            return URL(string: endpoint)
        }
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
