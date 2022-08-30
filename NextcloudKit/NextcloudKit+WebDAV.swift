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

    @objc public func createFolder(_ serverUrlFileName: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ ocId: String?, _ date: NSDate?, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        guard let url = serverUrlFileName.encodedToUrl else {
            return queue.async { completionHandler(account, nil, nil, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "MKCOL")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            return queue.async { completionHandler(account, nil, nil, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, nil, nil, error) }
            case .success( _):
                let ocId = NKCommon.shared.findHeader("oc-fileid", allHeaderFields: response.response?.allHeaderFields)
                if let dateString = NKCommon.shared.findHeader("date", allHeaderFields: response.response?.allHeaderFields) {
                    if let date = NKCommon.shared.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz") {
                        queue.async { completionHandler(account, ocId, date, .success) }
                    } else {
                        queue.async { completionHandler(account, nil, nil, .invalidDate) }
                    }
                } else {
                    queue.async { completionHandler(account, nil, nil, .invalidDate) }
                }
            }
        }
    }
     
    @objc public func deleteFileOrFolder(_ serverUrlFileName: String, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        guard let url = serverUrlFileName.encodedToUrl else {
            return queue.async { completionHandler(account, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "DELETE")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            return queue.async { completionHandler(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success( _):
                queue.async { completionHandler(account, .success) }
            }
        }
    }
     
    @objc public func moveFileOrFolder(serverUrlFileNameSource: String, serverUrlFileNameDestination: String, overwrite: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        guard let url = serverUrlFileNameSource.encodedToUrl else {
            return queue.async { completionHandler(account, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "MOVE")
         
        var headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        headers.update(name: "Destination", value: serverUrlFileNameDestination.urlEncoded ?? "")
        if overwrite {
            headers.update(name: "Overwrite", value: "T")
        } else {
            headers.update(name: "Overwrite", value: "F")
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            return queue.async { completionHandler(account, NKError(error: error)) }
        }
         
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success( _):
                queue.async { completionHandler(account, .success) }
            }
        }
    }
     
    @objc public func copyFileOrFolder(serverUrlFileNameSource: String, serverUrlFileNameDestination: String, overwrite: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account

        guard let url = serverUrlFileNameSource.encodedToUrl else {
            return queue.async { completionHandler(account, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "COPY")
         
        var headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        headers.update(name: "Destination", value: serverUrlFileNameDestination.urlEncoded ?? "")
        if overwrite {
            headers.update(name: "Overwrite", value: "T")
        } else {
            headers.update(name: "Overwrite", value: "F")
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            return queue.async { completionHandler(account, NKError(error: error)) }
        }

        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success( _):
                queue.async { completionHandler(account, .success) }
            }
        }
    }
     
    @objc public func readFileOrFolder(serverUrlFileName: String, depth: String, showHiddenFiles: Bool = true, requestBody: Data? = nil, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ files: [NKFile], _ responseData: Data?, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account
        var files: [NKFile] = []
        var serverUrlFileName = serverUrlFileName
        
        if depth == "1" && serverUrlFileName.last != "/" { serverUrlFileName = serverUrlFileName + "/" }
        if depth == "0" && serverUrlFileName.last == "/" { serverUrlFileName = String(serverUrlFileName.remove(at: serverUrlFileName.index(before: serverUrlFileName.endIndex))) }
        
        guard let url = serverUrlFileName.encodedToUrl else {
            return queue.async { completionHandler(account, files, nil, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "PROPFIND")
         
        var headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        headers.update(.contentType("application/xml"))
        headers.update(name: "Depth", value: depth)

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            if requestBody != nil {
                urlRequest.httpBody = requestBody!
                urlRequest.timeoutInterval = timeout
            } else {
                urlRequest.httpBody = NKDataFileXML().requestBodyFile.data(using: .utf8)
            }
        } catch {
            return queue.async { completionHandler(account, files, nil, NKError(error: error)) }
        }
        
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, files, nil, error) }
            case .success( _):
                if let data = response.data {
                    files = NKDataFileXML().convertDataFile(data: data, user: NKCommon.shared.user, userId: NKCommon.shared.userId, showHiddenFiles: showHiddenFiles)
                    queue.async { completionHandler(account, files, data, .success) }
                } else {
                    queue.async { completionHandler(account, files, nil, .xmlError) }
                }
            }
        }
    }
     
    @objc public func searchBodyRequest(serverUrl: String, requestBody: String, showHiddenFiles: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ files: [NKFile], _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account
        let httpBody = requestBody.data(using: .utf8)!
     
        search(serverUrl: serverUrl, httpBody: httpBody, showHiddenFiles: showHiddenFiles, customUserAgent: customUserAgent, addCustomHeaders: addCustomHeaders, account: account, timeout: timeout, queue: queue) { (account, files, error) in
            queue.async { completionHandler(account, files, error) }
        }
    }
    
    @objc public func searchLiteral(serverUrl: String, depth: String, literal: String, showHiddenFiles: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ files: [NKFile], _ error: NKError) -> Void) {
        let account = NKCommon.shared.account

        guard let href = ("/files/" + NKCommon.shared.userId).urlEncoded else {
            return queue.async { queue.async { completionHandler(account, [], .urlError) }}
        }
        
        let requestBody = String(format: NKDataFileXML().requestBodySearchFileName, href, depth, "%"+literal+"%")
        let httpBody = requestBody.data(using: .utf8)!
     
        search(serverUrl: serverUrl, httpBody: httpBody, showHiddenFiles: showHiddenFiles, customUserAgent: customUserAgent, addCustomHeaders: addCustomHeaders, account: account, timeout: timeout, queue: queue) { (account, files, error) in
            queue.async { completionHandler(account, files, error) }
        }
    }
    
    @objc public func searchMedia(path: String = "", lessDate: Any, greaterDate: Any, elementDate: String, limit: Int, showHiddenFiles: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ files: [NKFile], _ error: NKError) -> Void) {
            
        let account = NKCommon.shared.account
        let files: [NKFile] = []
        var greaterDateString: String?, lessDateString: String?
        
        guard let href = ("/files/" + NKCommon.shared.userId + path).urlEncoded else {
            return queue.async { completionHandler(account, files, .urlError) }
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
            return queue.async { completionHandler(account, files, .invalidDate) }
        }
        
        var requestBody = ""
        if limit > 0 {
            requestBody = String(format: NKDataFileXML().requestBodySearchMediaWithLimit, href, elementDate, elementDate, lessDateString!, elementDate, greaterDateString!, String(limit))
        } else {
            requestBody = String(format: NKDataFileXML().requestBodySearchMedia, href, elementDate, elementDate, lessDateString!, elementDate, greaterDateString!)
        }
        
        let httpBody = requestBody.data(using: .utf8)!
        
        search(serverUrl: NKCommon.shared.urlBase, httpBody: httpBody, showHiddenFiles: showHiddenFiles, customUserAgent: customUserAgent, addCustomHeaders: addCustomHeaders, account: account, timeout: timeout, queue: queue) { (account, files, error) in
            queue.async { completionHandler(account, files, error) }
        }
    }
     
    private func search(serverUrl: String, httpBody: Data, showHiddenFiles: Bool, customUserAgent: String?, addCustomHeaders: [String: String]?, account: String, timeout: TimeInterval, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ files: [NKFile], _ error: NKError) -> Void) {
         
        var files: [NKFile] = []
        
        guard let url = (serverUrl + "/" + NKCommon.shared.dav).encodedToUrl else {
            return queue.async { completionHandler(account, files, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "SEARCH")
         
        var headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        headers.update(.contentType("text/xml"))
         
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = httpBody
            urlRequest.timeoutInterval = timeout
        } catch {
            return queue.async { completionHandler(account, files, NKError(error: error)) }
        }
         
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, files, error) }
            case .success( _):
                if let data = response.data {
                    files = NKDataFileXML().convertDataFile(data: data, user: NKCommon.shared.user, userId: NKCommon.shared.userId, showHiddenFiles: showHiddenFiles)
                    queue.async { completionHandler(account, files, .success) }
                } else {
                    queue.async { completionHandler(account, files, .xmlError) }
                }
            }
        }
    }
     
    @objc public func setFavorite(fileName: String, favorite: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account
        let serverUrlFileName = NKCommon.shared.urlBase + "/" + NKCommon.shared.dav + "/files/" + NKCommon.shared.userId + "/" + fileName
        
        guard let url = serverUrlFileName.encodedToUrl else {
            return queue.async { completionHandler(account, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "PROPPATCH")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
         
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            let body = NSString.init(format: NKDataFileXML().requestBodyFileSetFavorite as NSString, (favorite ? 1 : 0)) as String
            urlRequest.httpBody = body.data(using: .utf8)
            urlRequest.timeoutInterval = timeout
        } catch {
            return queue.async { completionHandler(account, NKError(error: error)) }
        }
         
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).response(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, error) }
            case .success( _):
                queue.async { completionHandler(account, .success) }
            }
        }
    }
     
    @objc public func listingFavorites(showHiddenFiles: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ files: [NKFile], _ error: NKError) -> Void) {
         
        let account = NKCommon.shared.account
        let serverUrlFileName = NKCommon.shared.urlBase + "/" + NKCommon.shared.dav + "/files/" + NKCommon.shared.userId
        var files: [NKFile] = []

        guard let url = serverUrlFileName.encodedToUrl else {
            return queue.async { completionHandler(account, files, .urlError) }
        }
         
        let method = HTTPMethod(rawValue: "REPORT")
        
        let headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
         
        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML().requestBodyFileListingFavorites.data(using: .utf8)
            urlRequest.timeoutInterval = timeout
        } catch {
            return queue.async { completionHandler(account, files, NKError(error: error)) }
        }
         
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, files, error) }
            case .success( _):
                if let data = response.data {
                    files = NKDataFileXML().convertDataFile(data: data, user: NKCommon.shared.user, userId: NKCommon.shared.userId, showHiddenFiles: showHiddenFiles)
                    queue.async { completionHandler(account, files, .success) }
                } else {
                    queue.async { completionHandler(account, files, .xmlError) }
                }
            }
        }
    }
    
    @objc public func listingTrash(showHiddenFiles: Bool, customUserAgent: String? = nil, addCustomHeaders: [String: String]? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main, completionHandler: @escaping (_ account: String, _ items: [NKTrash], _ error: NKError) -> Void) {
           
        let account = NKCommon.shared.account
        var items: [NKTrash] = []
        let serverUrlFileName = NKCommon.shared.urlBase + "/" + NKCommon.shared.dav + "/trashbin/" + NKCommon.shared.userId + "/trash/"
            
        guard let url = serverUrlFileName.encodedToUrl else {
            return queue.async { completionHandler(account, items, .urlError) }
        }
        
        let method = HTTPMethod(rawValue: "PROPFIND")
             
        var headers = NKCommon.shared.getStandardHeaders(addCustomHeaders, customUserAgent: customUserAgent)
        headers.update(.contentType("application/xml"))
        headers.update(name: "Depth", value: "1")

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = NKDataFileXML().requestBodyTrash.data(using: .utf8)
            urlRequest.timeoutInterval = timeout
        } catch {
            return queue.async { completionHandler(account, items, NKError(error: error)) }
        }
             
        sessionManager.request(urlRequest).validate(statusCode: 200..<300).responseData(queue: NKCommon.shared.backgroundQueue) { (response) in
            debugPrint(response)
            
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response)
                queue.async { completionHandler(account, items, error) }
            case .success( _):
                if let data = response.data {
                    items = NKDataFileXML().convertDataTrash(data: data, showHiddenFiles: showHiddenFiles)
                    queue.async { completionHandler(account, items, .success) }
                } else {
                    queue.async { completionHandler(account, items, .xmlError) }
                }
            }
        }
    }
}
