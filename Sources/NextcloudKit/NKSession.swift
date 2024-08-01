//
//  NKSession.swift
//  
//
//  Created by Marino Faggiana on 20/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

public class NKSession {
    public var urlBase: String
    public var user: String
    public var userId: String
    public var password: String
    public let account: String
    public var userAgent: String
    public var nextcloudVersion: Int
    public let groupIdentifier: String?
    public let dav: String = "remote.php/dav"
    public var internalTypeIdentifiers: [NKCommon.UTTypeConformsToServer] = []
    public let sessionData: Alamofire.Session
    public let sessionDownloadBackground: URLSession
    public let sessionUploadBackground: URLSession
    public let sessionUploadBackgroundWWan: URLSession
    public let sessionUploadBackgroundExt: URLSession

    init(urlBase: String,
         user: String,
         userId: String,
         password: String,
         account: String,
         userAgent: String,
         nextcloudVersion: Int,
         groupIdentifier: String? = nil) {
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        self.password = password
        self.account = account
        self.userAgent = userAgent
        self.nextcloudVersion = nextcloudVersion
        self.groupIdentifier = groupIdentifier

        let backgroundSessionDelegate = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)
        /// Strange but works ?!?!
        let uuid = UUID().uuidString + "_" + user + "@" + urlBase
        let sharedCookieStorage = uuid

        /// Session Alamofire
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)

        sessionData = Alamofire.Session(configuration: configuration,
                                        delegate: NextcloudKit.shared,
                                        rootQueue: DispatchQueue(label: "com.nextcloud.session.rootQueue."+uuid),
                                        requestQueue: DispatchQueue(label: "com.nextcloud.session.requestQueue."+uuid),
                                        serializationQueue: DispatchQueue(label: "com.nextcloud.session.serializationQueue."+uuid),
                                        eventMonitors: [AlamofireLogger(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)])

        /// Session Download Background
        let configurationDownloadBackground = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionDownloadBackground)
        configurationDownloadBackground.allowsCellularAccess = true
        configurationDownloadBackground.sessionSendsLaunchEvents = true
        configurationDownloadBackground.isDiscretionary = false
        configurationDownloadBackground.httpMaximumConnectionsPerHost = 5
        configurationDownloadBackground.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        configurationDownloadBackground.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionDownloadBackground = URLSession(configuration: configurationDownloadBackground, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)

        /// Session Upload Background
        let configurationUploadBackground = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionUploadBackground)
        configurationUploadBackground.allowsCellularAccess = true
        configurationUploadBackground.sessionSendsLaunchEvents = true
        configurationUploadBackground.isDiscretionary = false
        configurationUploadBackground.httpMaximumConnectionsPerHost = 5
        configurationUploadBackground.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        configurationUploadBackground.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionUploadBackground = URLSession(configuration: configurationUploadBackground, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)

        /// Session Upload Background WWan
        let configurationUploadBackgroundWWan = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionUploadBackgroundWWan)
        configurationUploadBackgroundWWan.allowsCellularAccess = false
        configurationUploadBackgroundWWan.sessionSendsLaunchEvents = true
        configurationUploadBackgroundWWan.isDiscretionary = false
        configurationUploadBackgroundWWan.httpMaximumConnectionsPerHost = 5
        configurationUploadBackgroundWWan.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        configurationUploadBackgroundWWan.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionUploadBackgroundWWan = URLSession(configuration: configurationUploadBackgroundWWan, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)

        /// Session Upload Background Extension
        let configurationUploadBackgroundExt = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionUploadBackgroundExt)
        configurationUploadBackgroundExt.allowsCellularAccess = true
        configurationUploadBackgroundExt.sessionSendsLaunchEvents = true
        configurationUploadBackgroundExt.isDiscretionary = false
        configurationUploadBackgroundExt.httpMaximumConnectionsPerHost = 5
        configurationUploadBackgroundExt.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData
        configurationUploadBackgroundExt.sharedContainerIdentifier = groupIdentifier
        configurationUploadBackgroundExt.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionUploadBackgroundExt = URLSession(configuration: configurationUploadBackgroundExt, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)
    }
}
