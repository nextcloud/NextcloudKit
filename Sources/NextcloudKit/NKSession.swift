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
    public var nextcloudVersion: Int
    public let groupIdentifier: String
    public let httpMaximumConnectionsPerHost: Int
    public let httpMaximumConnectionsPerHostInDownload: Int
    public let httpMaximumConnectionsPerHostInUpload: Int
    public let requestCachePolicy: URLRequest.CachePolicy
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
         groupIdentifier: String,
         httpMaximumConnectionsPerHost: Int,
         httpMaximumConnectionsPerHostInDownload: Int,
         httpMaximumConnectionsPerHostInUpload: Int,
         requestCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) {
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        self.password = password
        self.account = account
        self.userAgent = userAgent
        self.nextcloudVersion = nextcloudVersion
        self.groupIdentifier = groupIdentifier
        self.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost
        self.httpMaximumConnectionsPerHostInDownload = httpMaximumConnectionsPerHostInDownload
        self.httpMaximumConnectionsPerHostInUpload = httpMaximumConnectionsPerHostInUpload
        self.requestCachePolicy = requestCachePolicy

        let backgroundSessionDelegate = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)
        /// Strange but works ?!?!
        let sharedCookieStorage = user + "@" + urlBase

        /// Session Alamofire
        let configuration = URLSessionConfiguration.af.default
        configuration.requestCachePolicy = requestCachePolicy
        configuration.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost

        #if os(iOS) || targetEnvironment(macCatalyst)
            configuration.multipathServiceType = .handover
        #endif

        configuration.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionData = Alamofire.Session(configuration: configuration,
                                        delegate: NextcloudKitSessionDelegate(nkCommonInstance: NextcloudKit.shared.nkCommonInstance),
                                        rootQueue: NextcloudKit.shared.nkCommonInstance.rootQueue,
                                        requestQueue: NextcloudKit.shared.nkCommonInstance.requestQueue,
                                        serializationQueue: NextcloudKit.shared.nkCommonInstance.serializationQueue,
                                        eventMonitors: [NKLogger(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)])

        /// Session Download Background
        let configurationDownloadBackground = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionDownloadBackground)
        configurationDownloadBackground.allowsCellularAccess = true

        if #available(macOS 11, *) {
            configurationDownloadBackground.sessionSendsLaunchEvents = true
        }

        configurationDownloadBackground.isDiscretionary = false
        configurationDownloadBackground.httpMaximumConnectionsPerHost = self.httpMaximumConnectionsPerHostInDownload
        configurationDownloadBackground.requestCachePolicy = requestCachePolicy

        #if os(iOS) || targetEnvironment(macCatalyst)
            configurationDownloadBackground.multipathServiceType = .handover
        #endif

        configurationDownloadBackground.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionDownloadBackground = URLSession(configuration: configurationDownloadBackground, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)

        /// Session Upload Background
        let configurationUploadBackground = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionUploadBackground)
        configurationUploadBackground.allowsCellularAccess = true

        if #available(macOS 11, *) {
            configurationUploadBackground.sessionSendsLaunchEvents = true
        }

        configurationUploadBackground.isDiscretionary = false
        configurationUploadBackground.httpMaximumConnectionsPerHost = self.httpMaximumConnectionsPerHostInUpload
        configurationUploadBackground.requestCachePolicy = requestCachePolicy

        #if os(iOS) || targetEnvironment(macCatalyst)
            configurationUploadBackground.multipathServiceType = .handover
        #endif

        configurationUploadBackground.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionUploadBackground = URLSession(configuration: configurationUploadBackground, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)

        /// Session Upload Background WWan
        let configurationUploadBackgroundWWan = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionUploadBackgroundWWan)
        configurationUploadBackgroundWWan.allowsCellularAccess = false

        if #available(macOS 11, *) {
            configurationUploadBackgroundWWan.sessionSendsLaunchEvents = true
        }

        configurationUploadBackgroundWWan.isDiscretionary = false
        configurationUploadBackgroundWWan.httpMaximumConnectionsPerHost = self.httpMaximumConnectionsPerHostInUpload
        configurationUploadBackgroundWWan.requestCachePolicy = requestCachePolicy
        configurationUploadBackgroundWWan.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionUploadBackgroundWWan = URLSession(configuration: configurationUploadBackgroundWWan, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)

        /// Session Upload Background Extension
        let configurationUploadBackgroundExt = URLSessionConfiguration.background(withIdentifier: NKCommon().identifierSessionUploadBackgroundExt + UUID().uuidString)
        configurationUploadBackgroundExt.allowsCellularAccess = true

        if #available(macOS 11, *) {
            configurationUploadBackgroundExt.sessionSendsLaunchEvents = true
        }

        configurationUploadBackgroundExt.isDiscretionary = false
        configurationUploadBackgroundExt.httpMaximumConnectionsPerHost = self.httpMaximumConnectionsPerHostInUpload
        configurationUploadBackgroundExt.requestCachePolicy = requestCachePolicy
        configurationUploadBackgroundExt.sharedContainerIdentifier = groupIdentifier

        #if os(iOS) || targetEnvironment(macCatalyst)
            configurationUploadBackgroundExt.multipathServiceType = .handover
        #endif

        configurationUploadBackgroundExt.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: sharedCookieStorage)
        sessionUploadBackgroundExt = URLSession(configuration: configurationUploadBackgroundExt, delegate: backgroundSessionDelegate, delegateQueue: OperationQueue.main)
    }
}
