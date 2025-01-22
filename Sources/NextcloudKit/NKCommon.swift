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

public protocol NextcloudKitDelegate: Sendable {
    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)

    func networkReachabilityObserver(_ typeReachability: NKCommon.TypeReachability)

    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)

    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError)
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError)

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>)
}

public class NKCommon: NSObject {
    public var nksessions = ThreadSafeArray<NKSession>()
    public var delegate: NextcloudKitDelegate?

    public let identifierSessionDownload: String = "com.nextcloud.nextcloudkit.session.download"
    public let identifierSessionUpload: String = "com.nextcloud.nextcloudkit.session.upload"
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

    public struct UTTypeConformsToServer: Sendable {
        var typeIdentifier: String
        var classFile: String
        var editor: String
        var iconName: String
        var name: String
        var account: String
    }

    internal var utiCache = NSCache<NSString, CFString>()
    internal var mimeTypeCache = NSCache<CFString, NSString>()
    internal var filePropertiesCache = NSCache<CFString, NKFileProperty>()
    internal var internalTypeIdentifiers = ThreadSafeArray<UTTypeConformsToServer>()

    public var filenamePathLog: String = ""
    public var levelLog: Int = 0
    public var copyLogToDocumentDirectory: Bool = false
    public var printLog: Bool = true

    private var internalFilenameLog: String = "communication.log"
    public var filenameLog: String {
        get {
            return internalFilenameLog
        }
        set(newVal) {
            if !newVal.isEmpty {
                internalFilenameLog = newVal
                internalFilenameLog = internalPathLog + "/" + internalFilenameLog
            }
        }
    }

    private var internalPathLog: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    public var pathLog: String {
        get {
            return internalPathLog
        }
        set(newVal) {
            var tempVal = newVal
            if tempVal.last == "/" {
                tempVal = String(tempVal.dropLast())
            }
            if !tempVal.isEmpty {
                internalPathLog = tempVal
                filenamePathLog = internalPathLog + "/" + internalFilenameLog
            }
        }
    }

    // MARK: - Init

    override init() {
        super.init()

        filenamePathLog = internalPathLog + "/" + internalFilenameLog
    }

    // MARK: - Type Identifier

    public func clearInternalTypeIdentifier(account: String) {
        internalTypeIdentifiers = internalTypeIdentifiers.filter({ $0.account != account })
    }

    public func addInternalTypeIdentifier(typeIdentifier: String, classFile: String, editor: String, iconName: String, name: String, account: String) {
        if !internalTypeIdentifiers.contains(where: { $0.typeIdentifier == typeIdentifier && $0.editor == editor && $0.account == account}) {
            let newUTI = UTTypeConformsToServer(typeIdentifier: typeIdentifier, classFile: classFile, editor: editor, iconName: iconName, name: name, account: account)
            internalTypeIdentifiers.append(newUTI)
        }
    }

    public func getInternalType(fileName: String, mimeType: String, directory: Bool, account: String) -> (mimeType: String, classFile: String, iconName: String, typeIdentifier: String, fileNameWithoutExt: String, ext: String) {
        var ext = (fileName as NSString).pathExtension.lowercased()
        var mimeType = mimeType
        var classFile = "", iconName = "", typeIdentifier = "", fileNameWithoutExt = ""
        var inUTI: CFString?

        if let cachedUTI = utiCache.object(forKey: ext as NSString) {
            inUTI = cachedUTI
        } else {
            if let unmanagedFileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil) {
                inUTI = unmanagedFileUTI.takeRetainedValue()
                if let inUTI {
                    utiCache.setObject(inUTI, forKey: ext as NSString)
                }
            }
        }

        if let inUTI = inUTI {
            typeIdentifier = inUTI as String
            fileNameWithoutExt = (fileName as NSString).deletingPathExtension

            // contentType detect
            if mimeType.isEmpty {
                if let cachedMimeUTI = mimeTypeCache.object(forKey: inUTI) {
                    mimeType = cachedMimeUTI as String
                } else {
                    if let mimeUTI = UTTypeCopyPreferredTagWithClass(inUTI, kUTTagClassMIMEType) {
                        let mimeUTIString = mimeUTI.takeRetainedValue() as String

                        mimeType = mimeUTIString
                        mimeTypeCache.setObject(mimeUTIString as NSString, forKey: inUTI)
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

                if let cachedFileProperties = filePropertiesCache.object(forKey: inUTI) {
                    fileProperties = cachedFileProperties
                } else {
                    fileProperties = getFileProperties(inUTI: inUTI)
                    filePropertiesCache.setObject(fileProperties, forKey: inUTI)
                }

                classFile = fileProperties.classFile
                iconName = fileProperties.iconName
            }
        }
        return(mimeType: mimeType, classFile: classFile, iconName: iconName, typeIdentifier: typeIdentifier, fileNameWithoutExt: fileNameWithoutExt, ext: ext)
    }

    public func getFileProperties(inUTI: CFString) -> NKFileProperty {
        var fileProperty = NKFileProperty()
        let typeIdentifier: String = inUTI as String

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
        } else {
            if let result = internalTypeIdentifiers.first(where: {$0.typeIdentifier == typeIdentifier}) {
                fileProperty.classFile = result.classFile
                fileProperty.iconName = result.iconName
                fileProperty.name = result.name
            } else {
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
                    print("Counter: \(counter)")
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

    // MARK: - Common

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

    public func convertDate(_ dateString: String, format: String) -> Date? {
        if dateString.isEmpty { return nil }
        let dateFormatter = DateFormatter()

        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = format
        guard let date = dateFormatter.date(from: dateString) else { return nil }
        return date
    }

    func convertDate(_ date: Date, format: String) -> String? {
        let dateFormatter = DateFormatter()

        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: date)
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
            print(error)
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

    // MARK: - Log

    public func clearFileLog() {
        FileManager.default.createFile(atPath: filenamePathLog, contents: nil, attributes: nil)
        if copyLogToDocumentDirectory, let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let filenameCopyToDocumentDirectory = path + "/" + filenameLog
            FileManager.default.createFile(atPath: filenameCopyToDocumentDirectory, contents: nil, attributes: nil)

        }
    }

    public func writeLog(_ text: String?) {
        guard let text = text else { return }
        guard let date = self.convertDate(Date(), format: "yyyy-MM-dd' 'HH:mm:ss") else { return }
        let textToWrite = "\(date) " + text + "\n"

        if printLog { print(textToWrite) }
        if levelLog > 0 {
            logQueue.async(flags: .barrier) {
                self.writeLogToDisk(filename: self.filenamePathLog, text: textToWrite)
                if self.copyLogToDocumentDirectory, let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                    let filenameCopyToDocumentDirectory = path + "/" + self.filenameLog
                    self.writeLogToDisk(filename: filenameCopyToDocumentDirectory, text: textToWrite)
                }
            }
        }
    }

    private func writeLogToDisk(filename: String, text: String) {
        guard let data = text.data(using: .utf8) else { return }

        if !FileManager.default.fileExists(atPath: filename) {
            FileManager.default.createFile(atPath: filename, contents: nil, attributes: nil)
        }

        if let fileHandle = FileHandle(forWritingAtPath: filename) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }
    }
 }
