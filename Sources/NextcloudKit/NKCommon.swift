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

    public enum TypeClassFile: String {
        case audio = "audio"
        case compress = "compress"
        case directory = "directory"
        case document = "document"
        case image = "image"
        case unknow = "unknow"
        case url = "url"
        case video = "video"
    }

    public enum TypeIconFile: String {
        case audio = "audio"
        case code = "code"
        case compress = "compress"
        case directory = "directory"
        case document = "document"
        case image = "image"
        case movie = "movie"
        case pdf = "pdf"
        case ppt = "ppt"
        case txt = "txt"
        case unknow = "file"
        case url = "url"
        case xls = "xls"
    }

   

#if swift(<6.0)
    internal var utiCache = NSCache<NSString, CFString>()
    internal var mimeTypeCache = NSCache<CFString, NSString>()
    internal var filePropertiesCache = NSCache<CFString, NKFileProperty>()
#else
    internal var utiCache = [String: String]()
    internal var mimeTypeCache = [String: String]()
    internal var filePropertiesCache = [String: NKFileProperty]()
#endif

    // MARK: - Init

    init() {

    }

    // MARK: - Type Identifier

    mutating public func getInternalType(fileName: String,
                                         mimeType: String,
                                         directory: Bool,
                                         account: String) ->
    (mimeType: String,
     classFile: String,
     iconName: String,
     typeIdentifier: String,
     fileNameWithoutExt: String,
     ext: String) {
        var ext = (fileName as NSString).pathExtension.lowercased()
        var mimeType = mimeType
        var classFile = "", iconName = "", typeIdentifier = "", fileNameWithoutExt = ""
        var inUTI: CFString?

#if swift(<6.0)
        if let cachedUTI = utiCache.object(forKey: ext as NSString) {
            inUTI = cachedUTI
        }
#else
        if let cachedUTI = utiCache[ext] {
            inUTI = cachedUTI as CFString
        }
#endif
        if inUTI == nil {
            if let unmanagedFileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil) {
                inUTI = unmanagedFileUTI.takeRetainedValue()
                if let inUTI {
#if swift(<6.0)
                    utiCache.setObject(inUTI, forKey: ext as NSString)
#else
                    utiCache[ext] = inUTI as String
#endif
                }
            }
        }

        if let inUTI {
            typeIdentifier = inUTI as String
            fileNameWithoutExt = (fileName as NSString).deletingPathExtension

            // contentType detect
            if mimeType.isEmpty {
#if swift(<6.0)
                if let cachedMimeUTI = mimeTypeCache.object(forKey: inUTI) {
                    mimeType = cachedMimeUTI as String
                }
#else
                if let cachedMimeUTI = mimeTypeCache[inUTI as String] {
                    mimeType = cachedMimeUTI
                }
#endif

                if mimeType.isEmpty {
                    if let mimeUTI = UTTypeCopyPreferredTagWithClass(inUTI, kUTTagClassMIMEType) {
                        let mimeUTIString = mimeUTI.takeRetainedValue() as String

                        mimeType = mimeUTIString
#if swift(<6.0)
                        mimeTypeCache.setObject(mimeUTIString as NSString, forKey: inUTI)
#else
                        mimeTypeCache[inUTI as String] = mimeUTIString as String
#endif
                    }
                }
            }

            if directory {
                mimeType = "httpd/unix-directory"
                classFile = TypeClassFile.directory.rawValue
                iconName = TypeIconFile.directory.rawValue
                typeIdentifier = kUTTypeFolder as String
                fileNameWithoutExt = fileName
                ext = ""
            } else {
                var fileProperties: NKFileProperty

#if swift(<6.0)
                if let cachedFileProperties = filePropertiesCache.object(forKey: inUTI) {
                    fileProperties = cachedFileProperties
                } else {
                    fileProperties = getFileProperties(inUTI: inUTI, account: account)
                    filePropertiesCache.setObject(fileProperties, forKey: inUTI)
                }
#else
                if let cachedFileProperties = filePropertiesCache[inUTI as String] {
                    fileProperties = cachedFileProperties
                } else {
                    fileProperties = getFileProperties(inUTI: inUTI)
                    filePropertiesCache[inUTI as String] = fileProperties
                }
#endif

                classFile = fileProperties.classFile
                iconName = fileProperties.iconName
            }
        }
        return(mimeType: mimeType, classFile: classFile, iconName: iconName, typeIdentifier: typeIdentifier, fileNameWithoutExt: fileNameWithoutExt, ext: ext)
    }

    public func getFileProperties(inUTI: CFString, account: String) -> NKFileProperty {
        let fileProperty = NKFileProperty()
        let typeIdentifier: String = inUTI as String
        let capabilities = NCCapabilities.shared.getCapabilitiesBlocking(for: account)

        if let fileExtension = UTTypeCopyPreferredTagWithClass(inUTI as CFString, kUTTagClassFilenameExtension) {
            fileProperty.ext = String(fileExtension.takeRetainedValue())
        }

        if UTTypeConformsTo(inUTI, kUTTypeImage) {
            fileProperty.classFile = TypeClassFile.image.rawValue
            fileProperty.iconName = TypeIconFile.image.rawValue
            fileProperty.name = "image"
        } else if UTTypeConformsTo(inUTI, kUTTypeMovie) {
            fileProperty.classFile = TypeClassFile.video.rawValue
            fileProperty.iconName = TypeIconFile.movie.rawValue
            fileProperty.name = "movie"
        } else if UTTypeConformsTo(inUTI, kUTTypeAudio) {
            fileProperty.classFile = TypeClassFile.audio.rawValue
            fileProperty.iconName = TypeIconFile.audio.rawValue
            fileProperty.name = "audio"
        } else if UTTypeConformsTo(inUTI, kUTTypeZipArchive) {
            fileProperty.classFile = TypeClassFile.compress.rawValue
            fileProperty.iconName = TypeIconFile.compress.rawValue
            fileProperty.name = "archive"
        } else if UTTypeConformsTo(inUTI, kUTTypeHTML) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.code.rawValue
            fileProperty.name = "code"
        } else if UTTypeConformsTo(inUTI, kUTTypePDF) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.pdf.rawValue
            fileProperty.name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeRTF) {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.txt.rawValue
            fileProperty.name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeText) {
            if fileProperty.ext.isEmpty { fileProperty.ext = "txt" }
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.txt.rawValue
            fileProperty.name = "text"
        } else if typeIdentifier == "text/plain" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.document.rawValue
            fileProperty.name = "markdown"
        } else if typeIdentifier == "text/html" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.document.rawValue
            fileProperty.name = "markdown"
        } else if typeIdentifier == "net.daringfireball.markdown" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.document.rawValue
            fileProperty.name = "markdown"
        } else if typeIdentifier == "text/x-markdown" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.document.rawValue
            fileProperty.name = "markdown"
        } else if typeIdentifier == "org.oasis-open.opendocument.text" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.document.rawValue
            fileProperty.name = "document"
        } else if typeIdentifier == "org.openxmlformats.wordprocessingml.document" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.document.rawValue
            fileProperty.name = "document"
        } else if typeIdentifier == "com.microsoft.word.doc" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.document.rawValue
            fileProperty.name = "document"
        } else if typeIdentifier == "com.apple.iwork.keynote.key" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.document.rawValue
            fileProperty.name = "pages"
        } else if typeIdentifier == "org.oasis-open.opendocument.spreadsheet" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.xls.rawValue
            fileProperty.name = "sheet"
        } else if typeIdentifier == "org.openxmlformats.spreadsheetml.sheet" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.xls.rawValue
            fileProperty.name = "sheet"
        } else if typeIdentifier == "com.microsoft.excel.xls" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.xls.rawValue
            fileProperty.name = "sheet"
        } else if typeIdentifier == "com.apple.iwork.numbers.numbers" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.xls.rawValue
            fileProperty.name = "numbers"
        } else if typeIdentifier == "org.oasis-open.opendocument.presentation" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.ppt.rawValue
            fileProperty.name = "presentation"
        } else if typeIdentifier == "org.openxmlformats.presentationml.presentation" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.ppt.rawValue
            fileProperty.name = "presentation"
        } else if typeIdentifier == "com.microsoft.powerpoint.ppt" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.ppt.rawValue
            fileProperty.name = "presentation"
        } else if typeIdentifier == "com.apple.iwork.keynote.key" {
            fileProperty.classFile = TypeClassFile.document.rawValue
            fileProperty.iconName = TypeIconFile.ppt.rawValue
            fileProperty.name = "keynote"
        } else {
            // Added UTI for Collabora
            for mimeType in capabilities.richDocumentsMimetypes {
                if typeIdentifier == mimeType {
                    fileProperty.classFile = TypeClassFile.document.rawValue
                    fileProperty.iconName = TypeIconFile.document.rawValue
                    fileProperty.name = "document"

                    return fileProperty
                }
            }



            if UTTypeConformsTo(inUTI, kUTTypeContent) {
                fileProperty.classFile = TypeClassFile.document.rawValue
                fileProperty.iconName = TypeIconFile.document.rawValue
                fileProperty.name = "document"
            } else {
                fileProperty.classFile = TypeClassFile.unknow.rawValue
                fileProperty.iconName = TypeIconFile.unknow.rawValue
                fileProperty.name = "file"
            }
        }
        return fileProperty
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
