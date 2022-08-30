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
import MobileCoreServices

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
    
    var user = ""
    var userId = ""
    var password = ""
    var account = ""
    var urlBase = ""
    var userAgent: String?
    var nextcloudVersion: Int = 0
    let webDav: String = "remote.php/dav"
    
    var cookies: [String:[HTTPCookie]] = [:]
    var internalTypeIdentifiers: [UTTypeConformsToServer] = []

    var delegate: NKCommonDelegate?
    
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
    
    private var _filenameLog: String = "communication.log"
    private var _pathLog: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    private var _filenamePathLog: String = ""
    private var _levelLog: Int = 0
    private var _printLog: Bool = true
    private var _copyLogToDocumentDirectory: Bool = false
    
    @objc public let backgroundQueue = DispatchQueue(label: "com.nextcloud.nextcloudkit.backgroundQueue", qos: .background, attributes: .concurrent)

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

    //MARK: - Init
    
    override init() {
        super.init()
        
        _filenamePathLog = _pathLog + "/" + _filenameLog
    }
    
    //MARK: - Setup
    
    @objc public func setup(account: String? = nil, user: String, userId: String, password: String, urlBase: String, userAgent: String, nextcloudVersion: Int, delegate: NKCommonDelegate?) {
        
        self.setup(account:account, user: user, userId: userId, password: password, urlBase: urlBase)
        self.setup(userAgent: userAgent)
        self.setup(nextcloudVersion: nextcloudVersion)
        self.setup(delegate: delegate)
    }
    
    @objc public func setup(account: String? = nil, user: String, userId: String, password: String, urlBase: String) {
        
        if self.account != account {
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: "changeUser"), object: nil)
        }
        
        if account == nil { self.account = "" } else { self.account = account! }
        self.user = user
        self.userId = userId
        self.password = password
        self.urlBase = urlBase
    }
    
    @objc public func setup(delegate: NKCommonDelegate?) {
        
        self.delegate = delegate
    }
    
    @objc public func setup(userAgent: String) {
        
        self.userAgent = userAgent
    }

    @objc public func setup(nextcloudVersion: Int) {
        
        self.nextcloudVersion = nextcloudVersion
    }
    
    //MARK: -
    
    @objc public func remove(account: String) {
        
        cookies[account] = nil
    }
        
    //MARK: -  Type Identifier
    
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
        
        // UTI
        if let unmanagedFileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil) {
            let inUTI = unmanagedFileUTI.takeRetainedValue()
            fileNameWithoutExt = (fileName as NSString).deletingPathExtension
            
            // contentType detect
            if mimeType == "" {
                if let mimeUTI = UTTypeCopyPreferredTagWithClass(inUTI, kUTTagClassMIMEType) {
                    mimeType = mimeUTI.takeRetainedValue() as String
                }
            }
            
            // TypeIdentifier
            typeIdentifier = inUTI as String

            if directory {
                mimeType = "httpd/unix-directory"
                classFile = typeClassFile.directory.rawValue
                iconName = typeIconFile.directory.rawValue
                typeIdentifier = kUTTypeFolder as String
                fileNameWithoutExt = fileName
                ext = ""
            } else {
                let result = getFileProperties(inUTI: inUTI)
                classFile = result.classFile
                iconName = result.iconName
            }
        }
        
        return(mimeType: mimeType, classFile: classFile, iconName: iconName, typeIdentifier: typeIdentifier, fileNameWithoutExt: fileNameWithoutExt, ext: ext)
    }
    
    public func getFileProperties(inUTI: CFString) -> (classFile: String, iconName: String, name: String, ext: String) {
    
        var classFile: String = ""
        var iconName: String = ""
        var name: String = ""
        var ext: String = ""
        let typeIdentifier: String = inUTI as String
        
        if let fileExtension = UTTypeCopyPreferredTagWithClass(inUTI as CFString, kUTTagClassFilenameExtension) {
            ext = String(fileExtension.takeRetainedValue())
        }
        
        if UTTypeConformsTo(inUTI, kUTTypeImage) {
            classFile = typeClassFile.image.rawValue
            iconName = typeIconFile.image.rawValue
            name = "image"
        } else if UTTypeConformsTo(inUTI, kUTTypeMovie) {
            classFile = typeClassFile.video.rawValue
            iconName = typeIconFile.movie.rawValue
            name = "movie"
        } else if UTTypeConformsTo(inUTI, kUTTypeAudio) {
            classFile = typeClassFile.audio.rawValue
            iconName = typeIconFile.audio.rawValue
            name = "audio"
        } else if UTTypeConformsTo(inUTI, kUTTypeZipArchive) {
            classFile = typeClassFile.compress.rawValue
            iconName = typeIconFile.compress.rawValue
            name = "archive"
        } else if UTTypeConformsTo(inUTI, kUTTypeHTML) {
            classFile = typeClassFile.document.rawValue
            iconName = typeIconFile.code.rawValue
            name = "code"
        } else if UTTypeConformsTo(inUTI, kUTTypePDF) {
            classFile = typeClassFile.document.rawValue
            iconName = typeIconFile.pdf.rawValue
            name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeRTF) {
            classFile = typeClassFile.document.rawValue
            iconName = typeIconFile.txt.rawValue
            name = "document"
        } else if UTTypeConformsTo(inUTI, kUTTypeText) {
            if ext == "" { ext = "txt" }
            classFile = typeClassFile.document.rawValue
            iconName = typeIconFile.txt.rawValue
            name = "text"
        } else {
            if let result = internalTypeIdentifiers.first(where: {$0.typeIdentifier == typeIdentifier}) {
                return(result.classFile, result.iconName, result.name, ext)
            } else {
                if UTTypeConformsTo(inUTI, kUTTypeContent) {
                    classFile = typeClassFile.document.rawValue
                    iconName = typeIconFile.document.rawValue
                    name = "document"
                } else {
                    classFile = typeClassFile.unknow.rawValue
                    iconName = typeIconFile.unknow.rawValue
                    name = "file"
                }
            }
        }
        
        return(classFile, iconName, name, ext)
    }
    
    //MARK: -  chunkedFile
    
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
    
    //MARK: - Common
    func getStandardHeaders(options: NKRequestOptions) -> HTTPHeaders {
         return getStandardHeaders(user: user, password: password, appendHeaders: options.customHeader, customUserAgent: options.customUserAgent, e2eToken: options.e2eToken)
     }

    func getStandardHeaders(_ appendHeaders: [String: String]?, customUserAgent: String?, e2eToken: String? = nil) -> HTTPHeaders {
        return getStandardHeaders(user: user, password: password, appendHeaders: appendHeaders, customUserAgent: customUserAgent, e2eToken: e2eToken)
    }
    
    func getStandardHeaders(user: String, password: String, appendHeaders: [String: String]?, customUserAgent: String?, e2eToken: String? = nil) -> HTTPHeaders {
        
        var headers: HTTPHeaders = [.authorization(username: user, password: password)]
        if customUserAgent != nil {
            headers.update(.userAgent(customUserAgent!))
        } else if let userAgent = userAgent {
            headers.update(.userAgent(userAgent))
        }
        headers.update(.contentType("application/x-www-form-urlencoded"))
        headers.update(name: "OCS-APIRequest", value: "true")
        if e2eToken != nil {
            headers.update(name: "e2e-token", value: e2eToken!)
        }
        
        for (key, value) in appendHeaders ?? [:] {
            headers.update(name: key, value: value)
        }
        
        return headers
    }
    
    func convertDate(_ dateString: String, format: String) -> NSDate? {
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = format
        if let date = dateFormatter.date(from: dateString) {
            return date as NSDate
        } else {
            return nil
        }
    }
    
    func convertDate(_ date: Date, format: String) -> String? {
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: date)
    }

    func createStandardUrl(serverUrl: String, endpoint: String) -> URLConvertible? {
        
        guard var serverUrl = serverUrl.urlEncoded else { return nil }
        if serverUrl.last != "/" { serverUrl = serverUrl + "/" }
        
        serverUrl = serverUrl + endpoint
        
        return serverUrl.asUrl
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
    
    //MARK: - Log

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
            
            writeLogToDisk(filename: filenamePathLog, text: textToWrite)
           
            if copyLogToDocumentDirectory {
                let filenameCopyToDocumentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + filenameLog
                writeLogToDisk(filename: filenameCopyToDocumentDirectory, text: textToWrite)
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

// MARK: - String URL encoding

extension String {
    var urlEncoded: String? {
        // +        for historical reason, most web servers treat + as a replacement of whitespace
        // ?, &     mark query pararmeter which should not be part of a url string, but added seperately
        let urlAllowedCharSet = CharacterSet.urlQueryAllowed.subtracting(["+", "?", "&"])
        return addingPercentEncoding(withAllowedCharacters: urlAllowedCharSet)
    }
    
    var encodedToUrl: URLConvertible? {
        return urlEncoded?.asUrl
    }
    
    var asUrl: URLConvertible? {
        return try? asURL()
    }
}
