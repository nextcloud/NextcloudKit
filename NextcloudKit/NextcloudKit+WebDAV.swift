//
//  NextcloudKit+WebDAV.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 07/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import SwiftyJSON

extension NextcloudKit {

    @objc public func createFolder(_ serverUrlFileName: String,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   completion: @escaping (_ account: String, _ ocId: String?, _ date: NSDate?, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "MKCOL")

        let headers = NKCommon.shared.getStandardHeaders(options: options)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, nil, nil, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, nil, nil, error) }
            case .success( _):
                let ocId = NKCommon.shared.findHeader("oc-fileid", allHeaderFields: response.response?.allHeaderFields)
                if let dateString = NKCommon.shared.findHeader("date", allHeaderFields: response.response?.allHeaderFields) {
                    if let date = NKCommon.shared.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz") {
                        options.queue.async { completion(account, ocId, date, .success) }
                    } else {
                        options.queue.async { completion(account, nil, nil, .invalidDate) }
                    }
                } else {
                    options.queue.async { completion(account, nil, nil, .invalidDate) }
                }
            }
        }
    }
     
    @objc public func deleteFileOrFolder(_ serverUrlFileName: String,
                                         options: NKRequestOptions = NKRequestOptions(),
                                         completion: @escaping (_ account: String, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }

        let headers = NKCommon.shared.getStandardHeaders(options: options)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .delete, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, error) }
            case .success( _):
                options.queue.async { completion(account, .success) }
            }
        }
    }
     
    @objc public func moveFileOrFolder(serverUrlFileNameSource: String,
                                       serverUrlFileNameDestination: String,
                                       overwrite: Bool,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       completion: @escaping (_ account: String, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        guard let url = serverUrlFileNameSource.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "MOVE")

        var headers = NKCommon.shared.getStandardHeaders(options: options)
        headers.update(name: "Destination", value: serverUrlFileNameDestination.urlEncoded ?? "")
        if overwrite {
            headers.update(name: "Overwrite", value: "T")
        } else {
            headers.update(name: "Overwrite", value: "F")
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }
         
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, error) }
            case .success( _):
                options.queue.async { completion(account, .success) }
            }
        }
    }
     
    @objc public func copyFileOrFolder(serverUrlFileNameSource: String,
                                       serverUrlFileNameDestination: String,
                                       overwrite: Bool,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       completion: @escaping (_ account: String, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        guard let url = serverUrlFileNameSource.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "COPY")

        var headers = NKCommon.shared.getStandardHeaders(options: options)
        headers.update(name: "Destination", value: serverUrlFileNameDestination.urlEncoded ?? "")
        if overwrite {
            headers.update(name: "Overwrite", value: "T")
        } else {
            headers.update(name: "Overwrite", value: "F")
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, error) }
            case .success( _):
                options.queue.async { completion(account, .success) }
            }
        }
    }
     
    @objc public func readFileOrFolder(serverUrlFileName: String,
                                       depth: String,
                                       showHiddenFiles: Bool = true,
                                       requestBody: Data? = nil,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       completion: @escaping (_ account: String, _ files: [NKFile], _ data: Data?, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        var files: [NKFile] = []
        var serverUrlFileName = serverUrlFileName

        if depth == "1" && serverUrlFileName.last != "/" { serverUrlFileName = serverUrlFileName + "/" }
        if depth == "0" && serverUrlFileName.last == "/" { serverUrlFileName = String(serverUrlFileName.remove(at: serverUrlFileName.index(before: serverUrlFileName.endIndex))) }
        
        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, files, nil, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "PROPFIND")

        var headers = NKCommon.shared.getStandardHeaders(options: options)
        headers.update(name: "Depth", value: depth)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            if requestBody != nil {
                urlRequest.httpBody = requestBody!
                urlRequest.timeoutInterval = options.timeout
            } else {
                urlRequest.httpBody = NKDataFileXML().requestBodyFile.data(using: .utf8)
            }
        } catch {
            return options.queue.async { completion(account, files, nil, NKError(error: error)) }
        }
        
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, files, nil, error) }
            case .success( _):
                if let xmlData = response.data {
                    files = NKDataFileXML().convertDataFile(xmlData: xmlData, user: NKCommon.shared.user, userId: NKCommon.shared.userId, showHiddenFiles: showHiddenFiles)
                    options.queue.async { completion(account, files, xmlData, .success) }
                } else {
                    options.queue.async { completion(account, files, nil, .xmlError) }
                }
            }
        }
    }
     
    @objc public func getFileFromFileId(_ fileId: String?,
                                        link: String?,
                                        options: NKRequestOptions = NKRequestOptions(),
                                        completion: @escaping (_ account: String, _ file: NKFile?, _ data: Data?, _ error: NKError) -> Void) {

        var httpBody: Data?

        if let fileId = fileId {
            httpBody = String(format: NKDataFileXML().requestBodySearchFileId, NKCommon.shared.userId, fileId).data(using: .utf8)!
        } else if let link = link {
            var linkArray = link.components(separatedBy: "/")
            if let fileId =  linkArray.last {
                httpBody = String(format: NKDataFileXML().requestBodySearchFileId, NKCommon.shared.userId, fileId).data(using: .utf8)!
            }
        }
        guard let httpBody = httpBody else {
            return options.queue.async { completion(NKCommon.shared.account, nil, nil, .urlError) }
        }

        search(serverUrl: NKCommon.shared.urlBase, httpBody: httpBody, showHiddenFiles: true, account: NKCommon.shared.account, options: options) { (account, files, data, error) in
            options.queue.async { completion(account, files.first, data, error) }
        }
    }

    @objc public func searchBodyRequest(serverUrl: String,
                                        requestBody: String,
                                        showHiddenFiles: Bool,
                                        options: NKRequestOptions = NKRequestOptions(),
                                        completion: @escaping (_ account: String, _ files: [NKFile], _ data: Data?, _ error: NKError) -> Void) {
         
        let httpBody = requestBody.data(using: .utf8)!
     
        search(serverUrl: serverUrl, httpBody: httpBody, showHiddenFiles: showHiddenFiles, account: NKCommon.shared.account, options: options) { (account, files, data, error) in
            options.queue.async { completion(account, files, data, error) }
        }
    }
    
    @objc public func searchLiteral(serverUrl: String,
                                    depth: String,
                                    literal: String,
                                    showHiddenFiles: Bool,
                                    options: NKRequestOptions = NKRequestOptions(),
                                    completion: @escaping (_ account: String, _ files: [NKFile], _ data: Data?, _ error: NKError) -> Void) {
        
        let account = NKCommon.shared.account

        guard let href = ("/files/" + NKCommon.shared.userId).urlEncoded else {
            return options.queue.async { completion(account, [], nil, .urlError) }
        }
        
        let requestBody = String(format: NKDataFileXML().requestBodySearchFileName, href, depth, "%"+literal+"%")
        let httpBody = requestBody.data(using: .utf8)!
     
        search(serverUrl: serverUrl, httpBody: httpBody, showHiddenFiles: showHiddenFiles, account: account, options: options) { (account, files, data, error) in
            options.queue.async { completion(account, files, data, error) }
        }
    }
    
    @objc public func searchMedia(path: String = "",
                                  lessDate: Any,
                                  greaterDate: Any,
                                  elementDate: String,
                                  limit: Int,
                                  showHiddenFiles: Bool,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  completion: @escaping (_ account: String, _ files: [NKFile], _ data: Data?, _ error: NKError) -> Void) {
            
        let account = NKCommon.shared.account

        let files: [NKFile] = []
        var greaterDateString: String?, lessDateString: String?
        
        guard let href = ("/files/" + NKCommon.shared.userId + path).urlEncoded else {
            return options.queue.async { completion(account, files, nil, .urlError) }
        }
        
        if lessDate is Date || lessDate is NSDate {
            lessDateString = NKCommon.shared.convertDate(lessDate as! Date, format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        } else if lessDate is Int {
            lessDateString = String(lessDate as! Int)
        }
        
        if greaterDate is Date || greaterDate is NSDate {
            greaterDateString = NKCommon.shared.convertDate(greaterDate as! Date, format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        } else if greaterDate is Int {
            greaterDateString = String(greaterDate as! Int)
        }
        
        if lessDateString == nil || greaterDateString == nil {
            return options.queue.async { completion(account, files, nil, .invalidDate) }
        }
        
        var requestBody = ""
        if limit > 0 {
            requestBody = String(format: NKDataFileXML().requestBodySearchMediaWithLimit, href, elementDate, elementDate, lessDateString!, elementDate, greaterDateString!, String(limit))
        } else {
            requestBody = String(format: NKDataFileXML().requestBodySearchMedia, href, elementDate, elementDate, lessDateString!, elementDate, greaterDateString!)
        }
        
        let httpBody = requestBody.data(using: .utf8)!
        
        search(serverUrl: NKCommon.shared.urlBase, httpBody: httpBody, showHiddenFiles: showHiddenFiles, account: account, options: options) { (account, files, data, error) in
            options.queue.async { completion(account, files, data, error) }
        }
    }

    private func search(serverUrl: String,
                        httpBody: Data,
                        showHiddenFiles: Bool,
                        account: String,
                        options: NKRequestOptions = NKRequestOptions(),
                        completion: @escaping (_ account: String, _ files: [NKFile], _ data: Data?, _ error: NKError) -> Void) {
         
        var files: [NKFile] = []
        
        guard let url = (serverUrl + "/" + NKCommon.shared.dav).encodedToUrl else {
            return options.queue.async { completion(account, files, nil, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "SEARCH")

        let headers = NKCommon.shared.getStandardHeaders(options.customHeader, customUserAgent: options.customUserAgent, contentType: "text/xml")

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = httpBody
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, files, nil, NKError(error: error)) }
        }
         
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, files, nil, error) }
            case .success( _):
                if let xmlData = response.data {
                    files = NKDataFileXML().convertDataFile(xmlData: xmlData, user: NKCommon.shared.user, userId: NKCommon.shared.userId, showHiddenFiles: showHiddenFiles)
                    options.queue.async { completion(account, files, xmlData, .success) }
                } else {
                    options.queue.async { completion(account, files, nil, .xmlError) }
                }
            }
        }
    }
     
    @objc public func setFavorite(fileName: String,
                                  favorite: Bool,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  completion: @escaping (_ account: String, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        let serverUrlFileName = NKCommon.shared.urlBase + "/" + NKCommon.shared.dav + "/files/" + NKCommon.shared.userId + "/" + fileName
        
        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "PROPPATCH")

        let headers = NKCommon.shared.getStandardHeaders(options: options)
         
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let body = NSString.init(format: NKDataFileXML().requestBodyFileSetFavorite as NSString, (favorite ? 1 : 0)) as String
            urlRequest.httpBody = body.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, NKError(error: error)) }
        }
         
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, error) }
            case .success( _):
                options.queue.async { completion(account, .success) }
            }
        }
    }
     
    @objc public func listingFavorites(showHiddenFiles: Bool,
                                       options: NKRequestOptions = NKRequestOptions(),
                                       completion: @escaping (_ account: String, _ files: [NKFile], _ data: Data?, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        let serverUrlFileName = NKCommon.shared.urlBase + "/" + NKCommon.shared.dav + "/files/" + NKCommon.shared.userId

        var files: [NKFile] = []

        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, files, nil, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "REPORT")

        let headers = NKCommon.shared.getStandardHeaders(options: options)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML().requestBodyFileListingFavorites.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, files, nil, NKError(error: error)) }
        }
         
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, files, nil, error) }
            case .success( _):
                if let xmlData = response.data {
                    files = NKDataFileXML().convertDataFile(xmlData: xmlData, user: NKCommon.shared.user, userId: NKCommon.shared.userId, showHiddenFiles: showHiddenFiles)
                    options.queue.async { completion(account, files, xmlData, .success) }
                } else {
                    options.queue.async { completion(account, files, nil, .xmlError) }
                }
            }
        }
    }
    
    @objc public func listingTrash(showHiddenFiles: Bool,
                                   options: NKRequestOptions = NKRequestOptions(),
                                   completion: @escaping (_ account: String, _ items: [NKTrash], _ data: Data?, _ error: NKError) -> Void) {
           
        let account = NKCommon.shared.account

        var items: [NKTrash] = []

        let serverUrlFileName = NKCommon.shared.urlBase + "/" + NKCommon.shared.dav + "/trashbin/" + NKCommon.shared.userId + "/trash/"
            
        guard let url = serverUrlFileName.encodedToUrl else {
            return options.queue.async { completion(account, items, nil, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "PROPFIND")
        
        var headers = NKCommon.shared.getStandardHeaders(options: options)
        headers.update(name: "Depth", value: "1")

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML().requestBodyTrash.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(account, items, nil, NKError(error: error)) }
        }
             
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                options.queue.async { completion(account, items, nil, error) }
            case .success( _):
                if let xmlData = response.data {
                    items = NKDataFileXML().convertDataTrash(xmlData: xmlData, showHiddenFiles: showHiddenFiles)
                    options.queue.async { completion(account, items, xmlData, .success) }
                } else {
                    options.queue.async { completion(account, items, nil, .xmlError) }
                }
            }
        }
    }
}
