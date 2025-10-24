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

open class NextcloudKit: @unchecked Sendable {
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

    /// Updates an existing `NKSession` stored in the synchronized array.
    ///
    /// This method looks up the session by its `account` identifier, applies any non-nil
    /// parameters to mutate the session, and then replaces the stored value using
    /// `SynchronizedNKSessionArray.replace(account:with:)`.
    ///
    /// - Parameters:
    ///   - account: The account identifier used to locate the session to update.
    ///   - urlBase: An optional new base URL for the session.
    ///   - user: An optional new username for the session.
    ///   - userId: An optional new user identifier for the session.
    ///   - password: An optional new password or token for the session.
    ///   - userAgent: An optional new User-Agent string for the session.
    public func updateSession(account: String,
                              urlBase: String? = nil,
                              user: String? = nil,
                              userId: String? = nil,
                              password: String? = nil,
                              userAgent: String? = nil) {
        guard var newSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            return
        }

        if let urlBase {
            newSession.urlBase = urlBase
        }
        if let user {
            newSession.user = user
        }
        if let userId {
            newSession.userId = userId
        }
        if let password {
            newSession.password = password
        }
        if let userAgent {
            newSession.userAgent = userAgent
        }
        nkCommonInstance.nksessions.replace(account: account, with: newSession)
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

    /// Evaluates a generic Alamofire response into NKError with simple HTTP-aware rules.
    /// - Note:
    ///   - Explicit cancellations return `.cancelled`.
    ///   - Any HTTP 2xx is considered success, regardless of body presence.
    ///   - If no HTTP status is available, fall back to Alamofire's `Result`.
    func evaluateResponse<Data>(_ response: AFDataResponse<Data>) -> NKError {
        // 1) Cancellations take precedence
        if let afError = response.error?.asAFError,
           afError.isExplicitlyCancelledError {
            return .cancelled
        }

        // 2) Prefer HTTP status code when available
        if let code = response.response?.statusCode {
            if (200...299).contains(code) {
                return .success
            }
            // Non-2xx: let the error flow below (even if serializer said "success")
        }

        // 3) Fall back to Alamofire's result (covers transport errors and missing status)
        switch response.result {
        case .success:
            return .success

        case .failure(let error):
            // No need to special-case inputDataNilOrZeroLength here:
            // - If it was a 2xx, we already returned above.
            // - If it's not 2xx or no status code, it's a real failure for our purposes.
            return NKError(error: error, afResponse: response, responseData: response.data)
        }
    }
}
