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
#endif

@objc public protocol NKCommonDelegate {
    
    @objc optional func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    @objc optional func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)
    
    @objc optional func networkReachabilityObserver(_ typeReachability: NKCommon.typeReachability)
    
    @objc optional func downloadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Int64, description: String?, task: URLSessionTask, error: NKError)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, error: NKError)
}

@objc public class NKCommon: NSObject {
    @objc public static var shared: NKCommon = {
        let instance = NKCommon()
        return instance
    }()

    var internalTypeIdentifiers: [UTTypeConformsToServer] = []
    var utiCache = NSCache<NSString, CFString>();
    var mimeTypeCache = NSCache<CFString, NSString>();
    var filePropertiesCache = NSCache<CFString, NKFileProperty>();
    var delegate: NKCommonDelegate?

    @objc public let dav: String = "remote.php/dav"

    @objc public let sessionIdentifierDownload: String = "com.nextcloud.nextcloudkit.session.download"
    @objc public let sessionIdentifierUpload: String = "com.nextcloud.nextcloudkit.session.upload"

    @objc public enum typeReachability: Int {
        case unknown = 0
        case notReachable = 1
        case reachableEthernetOrWiFi = 2
        case reachableCellular = 3
    }
    
    public enum typeClassFile: String {
        case audio = "audio"
        case compress = "compress"
        case directory = "directory"
        case document = "document"
        case image = "image"
        case unknow = "unknow"
        case url = "url"
        case video = "video"
    }
    
    public enum typeIconFile: String {
        case audio = "file_audio"
        case code = "file_code"
        case compress = "file_compress"
        case directory = "directory"
        case document = "document"
        case image = "file_photo"
        case movie = "file_movie"
        case pdf = "file_pdf"
        case ppt = "file_ppt"
        case txt = "file_txt"
        case unknow = "file"
        case url = "url"
        case xls = "file_xls"
    }

    public struct UTTypeConformsToServer {
        var typeIdentifier: String
        var classFile: String
        var editor: String
        var iconName: String
        var name: String
    }

    internal var _user = ""
    internal var _userId = ""
    internal var _password = ""
    internal var _account = ""
    internal var _urlBase = ""
    internal var _userAgent: String?
    internal var _nextcloudVersion: Int = 0

    private var _filenameLog: String = "communication.log"
    private var _pathLog: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    private var _filenamePathLog: String = ""
    private var _levelLog: Int = 0
    private var _printLog: Bool = true
    private var _copyLogToDocumentDirectory: Bool = false
    private let queueLog =  DispatchQueue (label: "com.nextcloud.nextcloudkit.queuelog", attributes: .concurrent )

    @objc public var user: String {
        get {
            return _user
        }
    }

    @objc public var userId: String {
        get {
            return _userId
        }
    }

    @objc public var password: String {
        get {
            return _password
        }
    }

    @objc public var account: String {
        get {
            return _account
        }
    }

    @objc public var urlBase: String {
        get {
            return _urlBase
        }
    }

    @objc public var userAgent: String? {
        get {
            return _userAgent
        }
    }

    @objc public var nextcloudVersion: Int {
        get {
            return _nextcloudVersion
        }
    }

    @objc public let backgroundQueue = DispatchQueue(label: "com.nextcloud.nextcloudkit.backgroundqueue", qos: .background, attributes: .concurrent)

    @objc public var filenameLog: String {
        get {
            return _filenameLog
        }
        set(newVal) {
            if newVal.count > 0 {
                _filenameLog = newVal
                _filenamePathLog = _pathLog + "/" + _filenameLog
            }
        }
    }
    
    @objc public var pathLog: String {
        get {
            return _pathLog
        }
        set(newVal) {
            var tempVal = newVal
            if tempVal.last == "/" {
                tempVal = String(tempVal.dropLast())
            }
            if tempVal.count > 0 {
                _pathLog = tempVal
                _filenamePathLog = _pathLog + "/" + _filenameLog
            }
        }
    }
    
    @objc public var filenamePathLog: String {
        get {
            return _filenamePathLog
        }
    }
    
    @objc public var levelLog: Int {
        get {
            return _levelLog
        }
        set(newVal) {
            _levelLog = newVal
        }
    }
    
    @objc public var printLog: Bool {
        get {
            return _printLog
        }
        set(newVal) {
            _printLog = newVal
        }
    }
    
    @objc public var copyLogToDocumentDirectory: Bool {
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

    // MARK: -  Type Identifier

    public func getInternalTypeIdentifier(typeIdentifier: String) -> [UTTypeConformsToServer] {
        
        var results: [UTTypeConformsToServer] = []
        
        for internalTypeIdentifier in internalTypeIdentifiers {
            if internalTypeIdentifier.typeIdentifier == typeIdentifier {
                results.append(internalTypeIdentifier)
            }
        }
        
        return results
    }
    
    @objc public func addInternalTypeIdentifier(typeIdentifier: String, classFile: String, editor: String, iconName: String, name: String) {
        
        if !internalTypeIdentifiers.contains(where: { $0.typeIdentifier == typeIdentifier && $0.editor == editor}) {
            let newUTI = UTTypeConformsToServer.init(typeIdentifier: typeIdentifier, classFile: classFile, editor: editor, iconName: iconName, name: name)
            internalTypeIdentifiers.append(newUTI)
        }
    }
    
    @objc public func objcGetInternalType(fileName: String, mimeType: String, directory: Bool) -> [String: String] {
                
        let results = getInternalType(fileName: fileName , mimeType: mimeType, directory: directory)
        
        return ["mimeType":results.mimeType, "classFile":results.classFile, "iconName":results.iconName, "typeIdentifier":results.typeIdentifier, "fileNameWithoutExt":results.fileNameWithoutExt, "ext":results.ext]
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
                utiCache.setObject(inUTI!, forKey: ext as NSString)
            }
        }

        if let inUTI = inUTI {
            typeIdentifier = inUTI as String
            fileNameWithoutExt = (fileName as NSString).deletingPathExtension

            // contentType detect
            if mimeType == "" {
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
                classFile = typeClassFile.directory.rawValue
                iconName = typeIconFile.directory.rawValue
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
            fileProperty.classFile = typeClassFile.image.rawValue
            fileProperty.iconName = typeIconFile.image.rawValue
            fileProperty.name = "image"
        } else if UTTypeConformsTo(inUTI, kUTTypeMovie) {
            fileProperty.classFile = typeClassFile.video.rawValue
            fileProperty.iconName = typeIconFile.movie.rawValue
            fileProperty.name = "movie"
        } else if UTTypeConformsTo(inUTI, kUTTypeAudio) {
            fileProperty.classFile = typeClassFile.audio.rawValue
            fileProperty.iconName = typeIconFile.audio.rawValue
            fileProperty.name = "audio"
        } else if UTTypeConformsTo(inUTI, kUTTypeZipArchive) {
            fileProperty.classFile = typeClassFile.compress.rawValue
            fileProperty.iconName = typeIconFile.compress.rawValue
            fileProperty.name = "archive"
        } else if UTTypeConformsTo(inUTI, kUTTypeHTML) {
            fileProperty.classFile = typeClassFile.document.rawValue
            fileProperty.iconName = typeIconFile.code.rawValue
            fileProperty.name = "code"
        } else if UTTypeConformsTo(inUTI, kUTTypePDF) {
            fileProperty.classFile = typeClassFile.document.rawValue
            fileProperty.iconName = typeIconFile.pdf.rawValue
            fileProperty.name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeRTF) {
            fileProperty.classFile = typeClassFile.document.rawValue
            fileProperty.iconName = typeIconFile.txt.rawValue
            fileProperty.name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeText) {
            if fileProperty.ext == "" { fileProperty.ext = "txt" }
            fileProperty.classFile = typeClassFile.document.rawValue
            fileProperty.iconName = typeIconFile.txt.rawValue
            fileProperty.name = "text"
        } else {
            if let result = internalTypeIdentifiers.first(where: {$0.typeIdentifier == typeIdentifier}) {
                fileProperty.classFile = result.classFile
                fileProperty.iconName = result.iconName
                fileProperty.name = result.name
            } else {
                if UTTypeConformsTo(inUTI, kUTTypeContent) {
                    fileProperty.classFile = typeClassFile.document.rawValue
                    fileProperty.iconName = typeIconFile.document.rawValue
                    fileProperty.name = "document"
                } else {
                    fileProperty.classFile = typeClassFile.unknow.rawValue
                    fileProperty.iconName = typeIconFile.unknow.rawValue
                    fileProperty.name = "file"
                }
            }
        }
        
        return fileProperty
    }
    
    // MARK: -  chunkedFile
    
    @objc public func chunkedFile(inputDirectory: String, outputDirectory: String, fileName: String, chunkSizeMB:Int, bufferSize: Int = 1000000) -> [String] {
        
        let fileManager: FileManager = .default
        var isDirectory: ObjCBool = false
        let chunkSize = chunkSizeMB * 1000000
        var outputFilesName: [String] = []
        var reader: FileHandle?
        var writer: FileHandle?
        var chunk: Int = 0
        var counter: Int = 0
        
        if !fileManager.fileExists(atPath:outputDirectory, isDirectory:&isDirectory) {
            do {
                try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return []
            }
        }
        
        do {
            reader = try .init(forReadingFrom: URL(fileURLWithPath: inputDirectory + "/" + fileName))
        } catch {
            return []
        }
        
        repeat {
            
            if autoreleasepool(invoking: { () -> Int in
                
                if chunk >= chunkSize {
                    writer?.closeFile()
                    writer = nil
                    chunk = 0
                    counter += 1
                    print("Counter: \(counter)")
                }
                
                let chunkRemaining: Int = chunkSize - chunk
                let buffer = reader?.readData(ofLength: min(bufferSize, chunkRemaining))
                
                if writer == nil {
                    let fileNameChunk = fileName + String(format: "%010d", counter)
                    let outputFileName = outputDirectory + "/" + fileNameChunk
                    fileManager.createFile(atPath: outputFileName, contents: nil, attributes: nil)
                    do {
                        writer = try .init(forWritingTo: URL(fileURLWithPath: outputFileName))
                    } catch {
                        outputFilesName = []
                        return 0
                    }
                    outputFilesName.append(fileNameChunk)
                }
                
                if let buffer = buffer {
                    writer?.write(buffer)
                    chunk = chunk + buffer.count
                    return buffer.count
                }
                return 0
                
            }) == 0 { break }
            
        } while true
        
        writer?.closeFile()
        reader?.closeFile()
        return outputFilesName
    }
    
    // MARK: - Common
    
    public func getStandardHeaders(options: NKRequestOptions) -> HTTPHeaders {
        return getStandardHeaders(user: user, password: password, appendHeaders: options.customHeader, customUserAgent: options.customUserAgent, contentType: options.contentType)
     }

    public func getStandardHeaders(_ appendHeaders: [String: String]? = nil, customUserAgent: String? = nil, contentType: String? = nil) -> HTTPHeaders {
        return getStandardHeaders(user: user, password: password, appendHeaders: appendHeaders, customUserAgent: customUserAgent, contentType: contentType)
    }
    
    public func getStandardHeaders(user: String, password: String, appendHeaders: [String: String]?, customUserAgent: String?, contentType: String? = nil) -> HTTPHeaders {
        
        var headers: HTTPHeaders = [.authorization(username: user, password: password)]

        if customUserAgent != nil {
            headers.update(.userAgent(customUserAgent!))
        } else if let userAgent = userAgent {
            headers.update(.userAgent(userAgent))
        }
        if let contentType = contentType {
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
    
    func convertDate(_ dateString: String, format: String) -> NSDate? {
        if dateString.isEmpty { return nil }

        let dateFormatter = DateFormatter()

        dateFormatter.locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = format

        guard let date = dateFormatter.date(from: dateString) as? NSDate else { return nil }
        return date
    }
    
    func convertDate(_ date: Date, format: String) -> String? {
        
        let dateFormatter = DateFormatter()

        dateFormatter.locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = format

        return dateFormatter.string(from: date)
    }

    func findHeader(_ header: String, allHeaderFields: [AnyHashable : Any]?) -> String? {
       
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

    // MARK: - Share account data from Nextcloud iOS & Nextcloud Talk

    @objc public func createDataAccountFile(at url: URL, accounts: [NKDataAccountFile]) -> Error? {

        do {
            let encode = try JSONEncoder().encode(accounts)
            try encode.write(to: url)
        } catch {
            return error
        }
        return nil
    }

    @objc public func readDataAccountFile(at url: URL) -> [NKDataAccountFile]? {

        do {
            let data = try Data(contentsOf: url)
            let accounts: [NKDataAccountFile] = try JSONDecoder().decode([NKDataAccountFile].self, from: data)
            return accounts
        } catch {
            return nil
        }
    }
    
    // MARK: - Log

    @objc public func clearFileLog() {

        FileManager.default.createFile(atPath: filenamePathLog, contents: nil, attributes: nil)
        if copyLogToDocumentDirectory {
            let filenameCopyToDocumentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + filenameLog
            FileManager.default.createFile(atPath: filenameCopyToDocumentDirectory, contents: nil, attributes: nil)

        }
    }
    
    @objc public func writeLog(_ text: String?) {
        
        guard let text = text else { return }
        guard let date = NKCommon.shared.convertDate(Date(), format: "yyyy-MM-dd' 'HH:mm:ss") else { return }
        let textToWrite = "\(date) " + text + "\n"

        if printLog {
            print(textToWrite)
        }
        
        if levelLog > 0 {

            queueLog.async(flags: .barrier) {
                self.writeLogToDisk(filename: self.filenamePathLog, text: textToWrite)

                if self.copyLogToDocumentDirectory {
                    let filenameCopyToDocumentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + self.filenameLog
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

