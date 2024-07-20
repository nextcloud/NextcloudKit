//
//  NKCommon.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 12/10/19.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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

#if os(iOS)
import MobileCoreServices
#else
import CoreServices
#endif

public protocol NKCommonDelegate {
    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)

    func networkReachabilityObserver(_ typeReachability: NKCommon.TypeReachability)

    func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    
    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: Date?, dateLastModified: Date?, length: Int64, task: URLSessionTask, error: NKError)
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: Date?, size: Int64, task: URLSessionTask, error: NKError)
}

public class NKCommon: NSObject {
    public let dav: String = "remote.php/dav"
    public let sessionIdentifierDownload: String = "com.nextcloud.nextcloudkit.session.download"
    public let sessionIdentifierUpload: String = "com.nextcloud.nextcloudkit.session.upload"

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

    public struct UTTypeConformsToServer {
        var typeIdentifier: String
        var classFile: String
        var editor: String
        var iconName: String
        var name: String
    }

    public let notificationCenterChunkedFileStop = NSNotification.Name(rawValue: "NextcloudKit.chunkedFile.stop")

    internal lazy var sessionConfiguration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.af.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        if let groupIdentifier {
            let cookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: groupIdentifier)
            configuration.httpCookieStorage = cookieStorage
        } else {
            configuration.httpCookieStorage = nil
        }
        return configuration
    }()
    internal var rootQueue: DispatchQueue = DispatchQueue(label: "com.nextcloud.nextcloudkit.sessionManagerData.rootQueue")
    internal var requestQueue: DispatchQueue?
    internal var serializationQueue: DispatchQueue?

    internal var _user = ""
    internal var _userId = ""
    internal var _password = ""
    internal var _account = ""
    internal var _urlBase = ""
    internal var _userAgent: String?
    internal var _nextcloudVersion: Int = 0
    internal var _groupIdentifier: String?

    internal var internalTypeIdentifiers: [UTTypeConformsToServer] = []
    internal var utiCache = NSCache<NSString, CFString>()
    internal var mimeTypeCache = NSCache<CFString, NSString>()
    internal var filePropertiesCache = NSCache<CFString, NKFileProperty>()
    internal var delegate: NKCommonDelegate?

    private var _filenameLog: String = "communication.log"
    private var _pathLog: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    private var _filenamePathLog: String = ""
    private var _levelLog: Int = 0
    private var _printLog: Bool = true
    private var _copyLogToDocumentDirectory: Bool = false
    private let queueLog = DispatchQueue(label: "com.nextcloud.nextcloudkit.queuelog", attributes: .concurrent )

    public var user: String {
        return _user
    }

    public var userId: String {
        return _userId
    }

    public var password: String {
        return _password
    }

    public var account: String {
        return _account
    }

    public var urlBase: String {
        return _urlBase
    }

    public var userAgent: String? {
        return _userAgent
    }

    public var nextcloudVersion: Int {
        return _nextcloudVersion
    }

    public var groupIdentifier: String? {
        return _groupIdentifier
    }

    public let backgroundQueue = DispatchQueue(label: "com.nextcloud.nextcloudkit.backgroundqueue", qos: .background, attributes: .concurrent)

    public var filenameLog: String {
        get {
            return _filenameLog
        }
        set(newVal) {
            if !newVal.isEmpty {
                _filenameLog = newVal
                _filenamePathLog = _pathLog + "/" + _filenameLog
            }
        }
    }

    public var pathLog: String {
        get {
            return _pathLog
        }
        set(newVal) {
            var tempVal = newVal
            if tempVal.last == "/" {
                tempVal = String(tempVal.dropLast())
            }
            if !tempVal.isEmpty {
                _pathLog = tempVal
                _filenamePathLog = _pathLog + "/" + _filenameLog
            }
        }
    }

    public var filenamePathLog: String {
        return _filenamePathLog
    }

    public var levelLog: Int {
        get {
            return _levelLog
        }
        set(newVal) {
            _levelLog = newVal
        }
    }

    public var printLog: Bool {
        get {
            return _printLog
        }
        set(newVal) {
            _printLog = newVal
        }
    }

    public var copyLogToDocumentDirectory: Bool {
        get {
            return _copyLogToDocumentDirectory
        }
        set(newVal) {
            _copyLogToDocumentDirectory = newVal
        }
    }

    // MARK: - Init

    override init() {
        super.init()

        _filenamePathLog = _pathLog + "/" + _filenameLog
    }

    // MARK: - Type Identifier

    public func getInternalTypeIdentifier(typeIdentifier: String) -> [UTTypeConformsToServer] {
        var results: [UTTypeConformsToServer] = []

        for internalTypeIdentifier in internalTypeIdentifiers {
            if internalTypeIdentifier.typeIdentifier == typeIdentifier {
                results.append(internalTypeIdentifier)
            }
        }
        return results
    }

    public func addInternalTypeIdentifier(typeIdentifier: String, classFile: String, editor: String, iconName: String, name: String) {
        if !internalTypeIdentifiers.contains(where: { $0.typeIdentifier == typeIdentifier && $0.editor == editor}) {
            let newUTI = UTTypeConformsToServer(typeIdentifier: typeIdentifier, classFile: classFile, editor: editor, iconName: iconName, name: name)
            internalTypeIdentifiers.append(newUTI)
        }
    }

    public func objcGetInternalType(fileName: String, mimeType: String, directory: Bool) -> [String: String] {
        let results = getInternalType(fileName: fileName, mimeType: mimeType, directory: directory)
        return ["mimeType": results.mimeType, "classFile": results.classFile, "iconName": results.iconName, "typeIdentifier": results.typeIdentifier, "fileNameWithoutExt": results.fileNameWithoutExt, "ext": results.ext]
    }

    public func getInternalType(fileName: String, mimeType: String, directory: Bool) -> (mimeType: String, classFile: String, iconName: String, typeIdentifier: String, fileNameWithoutExt: String, ext: String) {
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
        let fileProperty = NKFileProperty()
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

    public func getStandardHeaders(options: NKRequestOptions) -> HTTPHeaders {
        return getStandardHeaders(user: user, password: password, appendHeaders: options.customHeader, customUserAgent: options.customUserAgent, contentType: options.contentType)
    }

    public func getStandardHeaders(_ appendHeaders: [String: String]? = nil, customUserAgent: String? = nil, contentType: String? = nil) -> HTTPHeaders {
        return getStandardHeaders(user: user, password: password, appendHeaders: appendHeaders, customUserAgent: customUserAgent, contentType: contentType)
    }

    public func getStandardHeaders(user: String?, password: String?, appendHeaders: [String: String]?, customUserAgent: String?, contentType: String? = nil) -> HTTPHeaders {
        var headers: HTTPHeaders = []

        if let user, let password {
            headers.update(.authorization(username: user, password: password))
        }
        if let customUserAgent {
            headers.update(.userAgent(customUserAgent))
        } else if let userAgent = userAgent {
            headers.update(.userAgent(userAgent))
        }
        if let contentType {
            headers.update(.contentType(contentType))
        } else {
            headers.update(.contentType("application/x-www-form-urlencoded"))
        }
        if contentType != "application/xml" {
            headers.update(name: "Accept", value: "application/json")
        }
        headers.update(name: "OCS-APIRequest", value: "true")
        for (key, value) in appendHeaders ?? [:] {
            headers.update(name: key, value: value)
        }
        return headers
    }

    public func createStandardUrl(serverUrl: String, endpoint: String) -> URLConvertible? {
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

    public func returnPathfromServerUrl(_ serverUrl: String) -> String {
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
            queueLog.async(flags: .barrier) {
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
