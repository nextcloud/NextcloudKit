// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@preconcurrency import Alamofire

public struct NKSession: Sendable {
    public var urlBase: String
    public var user: String
    public var userId: String
    public var password: String
    public var account: String
    public var userAgent: String
    public let groupIdentifier: String
    public let httpMaximumConnectionsPerHost: Int
    public let httpMaximumConnectionsPerHostInDownload: Int
    public let httpMaximumConnectionsPerHostInUpload: Int
    public let dav: String = "remote.php/dav"
    public var sharedCookieStorage = ""
    public let sessionData: Alamofire.Session
    public let sessionDataNoCache: Alamofire.Session
    public let sessionDownloadBackground: URLSession
    public let backgroundSessionDelegate: URLSessionDelegate?
    public let sessionUploadBackground: URLSession
    public let sessionUploadBackgroundWWan: URLSession

    public lazy var sessionDownloadBackgroundExt: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionDownloadBackgroundExt)
        config.sharedContainerIdentifier = groupIdentifier
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.allowsCellularAccess = true
        config.requestCachePolicy = .useProtocolCachePolicy
        config.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHostInDownload
        config.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        #if os(iOS) || targetEnvironment(macCatalyst)
        config.multipathServiceType = .handover
        #endif
        return URLSession(configuration: config, delegate: backgroundSessionDelegate, delegateQueue: .main)
    }()

    public lazy var sessionUploadBackgroundExt: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionUploadBackgroundExt)
        config.sharedContainerIdentifier = groupIdentifier
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.allowsCellularAccess = true
        config.requestCachePolicy = .useProtocolCachePolicy
        config.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHostInUpload
        config.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        #if os(iOS) || targetEnvironment(macCatalyst)
        config.multipathServiceType = .handover
        #endif
        return URLSession(configuration: config, delegate: backgroundSessionDelegate, delegateQueue: .main)
    }()

    init(nkCommonInstance: NKCommon,
         urlBase: String,
         user: String,
         userId: String,
         password: String,
         account: String,
         userAgent: String,
         groupIdentifier: String,
         httpMaximumConnectionsPerHost: Int,
         httpMaximumConnectionsPerHostInDownload: Int,
         httpMaximumConnectionsPerHostInUpload: Int) {
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        self.password = password
        self.account = account
        self.userAgent = userAgent
        self.groupIdentifier = groupIdentifier
        self.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost
        self.httpMaximumConnectionsPerHostInDownload = httpMaximumConnectionsPerHostInDownload
        self.httpMaximumConnectionsPerHostInUpload = httpMaximumConnectionsPerHostInUpload
        self.backgroundSessionDelegate = NKBackground(nkCommonInstance: nkCommonInstance)

        // Strange but works ?!?!
        sharedCookieStorage = user + "@" + urlBase

        // SessionData Alamofire
        let configurationSessionData = URLSessionConfiguration.af.default
        configurationSessionData.requestCachePolicy = .useProtocolCachePolicy
        configurationSessionData.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost

        #if os(iOS) || targetEnvironment(macCatalyst)
        configurationSessionData.multipathServiceType = .handover
        #endif

        configurationSessionData.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionData = Alamofire.Session(configuration: configurationSessionData,
                                        delegate: NextcloudKitSessionDelegate(nkCommonInstance: nkCommonInstance),
                                        rootQueue: nkCommonInstance.rootQueue,
                                        requestQueue: nkCommonInstance.requestQueue,
                                        serializationQueue: nkCommonInstance.serializationQueue,
                                        eventMonitors: [NKMonitor(nkCommonInstance: nkCommonInstance)])

        // SessionDataNoCache Alamofire
        let configurationSessionDataNoCache = URLSessionConfiguration.af.default
        configurationSessionDataNoCache.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configurationSessionDataNoCache.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost
        configurationSessionDataNoCache.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)

        sessionDataNoCache = Alamofire.Session(configuration: configurationSessionDataNoCache,
                                               delegate: NextcloudKitSessionDelegate(nkCommonInstance: nkCommonInstance),
                                               rootQueue: nkCommonInstance.rootQueue,
                                               requestQueue: nkCommonInstance.requestQueue,
                                               serializationQueue: nkCommonInstance.serializationQueue,
                                               eventMonitors: [NKMonitor(nkCommonInstance: nkCommonInstance)])

        // Session Download Background
        let configurationDownloadBackground = URLSessionConfiguration.background(withIdentifier: NKCommon().getSessionConfigurationIdentifier(NKCommon().identifierSessionDownloadBackground, account: account))
        configurationDownloadBackground.allowsCellularAccess = true

        if #available(macOS 11, *) {
            configurationDownloadBackground.sessionSendsLaunchEvents = true
        }

        configurationDownloadBackground.isDiscretionary = false
        configurationDownloadBackground.httpMaximumConnectionsPerHost = self.httpMaximumConnectionsPerHostInDownload
        configurationDownloadBackground.requestCachePolicy = .useProtocolCachePolicy

        #if os(iOS) || targetEnvironment(macCatalyst)
            configurationDownloadBackground.multipathServiceType = .handover
        #endif

        configurationDownloadBackground.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionDownloadBackground = URLSession(configuration: configurationDownloadBackground, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)

        // Session Upload Background
        let configurationUploadBackground = URLSessionConfiguration.background(withIdentifier: NKCommon().getSessionConfigurationIdentifier(NKCommon().identifierSessionUploadBackground, account: account))
        configurationUploadBackground.allowsCellularAccess = true

        if #available(macOS 11, *) {
            configurationUploadBackground.sessionSendsLaunchEvents = true
        }

        configurationUploadBackground.isDiscretionary = false
        configurationUploadBackground.httpMaximumConnectionsPerHost = self.httpMaximumConnectionsPerHostInUpload
        configurationUploadBackground.requestCachePolicy = .useProtocolCachePolicy

        #if os(iOS) || targetEnvironment(macCatalyst)
            configurationUploadBackground.multipathServiceType = .handover
        #endif

        configurationUploadBackground.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionUploadBackground = URLSession(configuration: configurationUploadBackground, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)

        // Session Upload Background WWan
        let configurationUploadBackgroundWWan = URLSessionConfiguration.background(withIdentifier: NKCommon().getSessionConfigurationIdentifier(NKCommon().identifierSessionUploadBackgroundWWan, account: account))
        configurationUploadBackgroundWWan.allowsCellularAccess = false

        if #available(macOS 11, *) {
            configurationUploadBackgroundWWan.sessionSendsLaunchEvents = true
        }

        configurationUploadBackgroundWWan.isDiscretionary = false
        configurationUploadBackgroundWWan.httpMaximumConnectionsPerHost = self.httpMaximumConnectionsPerHostInUpload
        configurationUploadBackgroundWWan.requestCachePolicy = .useProtocolCachePolicy
        configurationUploadBackgroundWWan.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionUploadBackgroundWWan = URLSession(configuration: configurationUploadBackgroundWWan, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)
    }
}
