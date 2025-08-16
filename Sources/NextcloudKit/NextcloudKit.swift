// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

#if os(macOS)
import Foundation
#else
import UIKit
#endif
import Alamofire
import SwiftyJSON

open class NextcloudKit {
#if swift(<6.0)
    public static let shared: NextcloudKit = {
        let instance = NextcloudKit()
        return instance
    }()
#endif
#if !os(watchOS)
    private let reachabilityManager = Alamofire.NetworkReachabilityManager()
#endif
    public var nkCommonInstance = NKCommon()

    internal func log(debug message: String, minimumLogLevel: NKLogLevel = .compact) {
        NKLogFileManager.shared.writeLog(debug: message, minimumLogLevel: minimumLogLevel)
    }

    internal lazy var unauthorizedSession: Alamofire.Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        return Alamofire.Session(configuration: configuration,
                                 delegate: NextcloudKitSessionDelegate(nkCommonInstance: nkCommonInstance),
                                 eventMonitors: [NKMonitor(nkCommonInstance: self.nkCommonInstance)])
    }()

#if swift(<6.0)
    init() {
#if !os(watchOS)
        startNetworkReachabilityObserver()
#endif
    }
#else
    public init() {
#if !os(watchOS)
        startNetworkReachabilityObserver()
#endif
    }
#endif

    deinit {
#if !os(watchOS)
        stopNetworkReachabilityObserver()
#endif
    }

    // MARK: - Session setup

    public func setup(groupIdentifier: String? = nil,
                      delegate: NextcloudKitDelegate? = nil,
                      memoryCapacity: Int = 30,
                      diskCapacity: Int = 500,
                      removeAllCachedResponses: Bool = false) {
        self.nkCommonInstance.delegate = delegate
        self.nkCommonInstance.groupIdentifier = groupIdentifier

        /// Cache URLSession
        ///
        let memoryCapacity = memoryCapacity * 1024 * 1024   // default 30 MB in RAM
        let diskCapacity = diskCapacity * 1024 * 1024       // default 500 MB on Disk
        let urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)
        URLCache.shared = urlCache

        if removeAllCachedResponses {
            URLCache.shared.removeAllCachedResponses()
        }
    }

    public func appendSession(account: String,
                              urlBase: String,
                              user: String,
                              userId: String,
                              password: String,
                              userAgent: String,
                              httpMaximumConnectionsPerHost: Int = 6,
                              httpMaximumConnectionsPerHostInDownload: Int = 6,
                              httpMaximumConnectionsPerHostInUpload: Int = 6,
                              groupIdentifier: String) {
        if nkCommonInstance.nksessions.contains(account: account) {
            return updateSession(account: account, urlBase: urlBase, userId: userId, password: password, userAgent: userAgent)
        }

        let nkSession = NKSession(
            nkCommonInstance: nkCommonInstance,
            urlBase: urlBase,
            user: user,
            userId: userId,
            password: password,
            account: account,
            userAgent: userAgent,
            groupIdentifier: groupIdentifier,
            httpMaximumConnectionsPerHost: httpMaximumConnectionsPerHost,
            httpMaximumConnectionsPerHostInDownload: httpMaximumConnectionsPerHostInDownload,
            httpMaximumConnectionsPerHostInUpload: httpMaximumConnectionsPerHostInUpload
        )

        nkCommonInstance.nksessions.append(nkSession)
    }

    public func updateSession(account: String,
                              urlBase: String? = nil,
                              user: String? = nil,
                              userId: String? = nil,
                              password: String? = nil,
                              userAgent: String? = nil,
                              replaceWithAccount: String? = nil) {
        guard var nkSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            return
        }

        if let urlBase {
            nkSession.urlBase = urlBase
        }
        if let user {
            nkSession.user = user
        }
        if let userId {
            nkSession.userId = userId
        }
        if let password {
            nkSession.password = password
        }
        if let userAgent {
            nkSession.userAgent = userAgent
        }
        if let replaceWithAccount {
            nkSession.account = replaceWithAccount
        }
    }

    public func deleteCookieStorageForAccount(_ account: String) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            return
        }

        if let cookieStore = nkSession.sessionData.session.configuration.httpCookieStorage {
            for cookie in cookieStore.cookies ?? [] {
                cookieStore.deleteCookie(cookie)
            }
        }
    }

    // MARK: - Reachability

#if !os(watchOS)
    public func isNetworkReachable() -> Bool {
        return reachabilityManager?.isReachable ?? false
    }

    private func startNetworkReachabilityObserver() {
        reachabilityManager?.startListening(onUpdatePerforming: { status in
            switch status {
            case .unknown:
                self.nkCommonInstance.delegate?.networkReachabilityObserver(.unknown)
            case .notReachable:
                self.nkCommonInstance.delegate?.networkReachabilityObserver(.notReachable)
            case .reachable(.ethernetOrWiFi):
                self.nkCommonInstance.delegate?.networkReachabilityObserver(.reachableEthernetOrWiFi)
            case .reachable(.cellular):
                self.nkCommonInstance.delegate?.networkReachabilityObserver(.reachableCellular)
            }
        })
    }

    private func stopNetworkReachabilityObserver() {
        reachabilityManager?.stopListening()
    }
#endif

    /*
    /// Evaluates an Alamofire response and returns the appropriate NKError.
    func evaluateResponse<Data>(_ response: AFDataResponse<Data>) -> NKError {
        // Treat explicit cancellations as a first-class outcome
        if let afError = response.error?.asAFError,
            afError.isExplicitlyCancelledError {
            return .cancelled
        }

        switch response.result {
        case .failure(let error):
            if let afError = error.asAFError,
               case .responseSerializationFailed(let reason) = afError,
               case .inputDataNilOrZeroLength = reason {
                return .success
            } else {
                return NKError(error: error, afResponse: response, responseData: response.data)
            }
        case .success:
            return .success
        }
    }
    */
    
    /// Evaluates an Alamofire response and returns the appropriate NKError.
    func evaluateResponse<Data>(_ response: AFDataResponse<Data>) -> NKError {
        // Treat explicit cancellations as a first-class outcome
        if let afError = response.error?.asAFError,
            afError.isExplicitlyCancelledError {
            return .cancelled
        }

        // Prefer HTTP status code over serializer outcome for uploads
        let statusCode = response.response?.statusCode
        if let code = statusCode {
            // Success on any 2xx; explicitly include 204/205 which carry no body by definition
            if (200...299).contains(code) || code == 204 || code == 205 {
                return .success
            }
        }

        // Fall back to Alamofire's result only if HTTP status wasn't clearly successful
        switch response.result {
        case .success:
            return .success

        case .failure(let error):
            // If the only failure reason is "no data" but status is actually OK, still succeed
            if let afError = error.asAFError,
               case .responseSerializationFailed(let reason) = afError,
               case .inputDataNilOrZeroLength = reason,
               let code = statusCode,
               (200...299).contains(code) || code == 204 || code == 205 {
                return .success
            }

            // Everything else is a real error: keep the payload for diagnostics
            return NKError(error: error, afResponse: response, responseData: response.data)
        }
    }
}
