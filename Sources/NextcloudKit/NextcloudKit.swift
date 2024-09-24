//
//  NextcloudKit.swift
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

#if os(macOS)
import Foundation
#else
import UIKit
#endif
import Alamofire
import SwiftyJSON

open class NextcloudKit {
    public static let shared: NextcloudKit = {
        let instance = NextcloudKit()
        return instance
    }()
#if !os(watchOS)
    private let reachabilityManager = Alamofire.NetworkReachabilityManager()
#endif
    public let nkCommonInstance = NKCommon()
    internal lazy var internalSession: Alamofire.Session = {
        return Alamofire.Session(configuration: URLSessionConfiguration.af.default,
                                 delegate: NextcloudKitSessionDelegate(nkCommonInstance: nkCommonInstance),
                                 eventMonitors: [NKLogger(nkCommonInstance: self.nkCommonInstance)])
    }()

    init() {
#if !os(watchOS)
        startNetworkReachabilityObserver()
#endif
    }

    deinit {
#if !os(watchOS)
        stopNetworkReachabilityObserver()
#endif
    }

    // MARK: - Session setup

    public func setup(delegate: NextcloudKitDelegate?) {
        self.nkCommonInstance.delegate = delegate
    }

    public func appendSession(account: String,
                              urlBase: String,
                              user: String,
                              userId: String,
                              password: String,
                              userAgent: String,
                              nextcloudVersion: Int,
                              groupIdentifier: String) {
        if nkCommonInstance.nksessions.filter({ $0.account == account }).first != nil {
            return updateSession(account: account, urlBase: urlBase, userId: userId, password: password, userAgent: userAgent, nextcloudVersion: nextcloudVersion)
        }
        let nkSession = NKSession(urlBase: urlBase, user: user, userId: userId, password: password, account: account, userAgent: userAgent, nextcloudVersion: nextcloudVersion, groupIdentifier: groupIdentifier)

        nkCommonInstance.nksessions.append(nkSession)
    }

    public func updateSession(account: String,
                              urlBase: String? = nil,
                              user: String? = nil,
                              userId: String? = nil,
                              password: String? = nil,
                              userAgent: String? = nil,
                              nextcloudVersion: Int? = nil,
                              replaceWithAccount: String? = nil) {
        guard let nkSession = nkCommonInstance.nksessions.filter({ $0.account == account }).first else { return }
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
        if let nextcloudVersion {
            nkSession.nextcloudVersion = nextcloudVersion
        }
        if let replaceWithAccount {
            nkSession.account = replaceWithAccount
        }
    }

    public func removeSession(account: String) {
        if let index = nkCommonInstance.nksessions.index(where: { $0.account == account}) {
            nkCommonInstance.nksessions.remove(at: index)
        }
    }

    public func getSessionhttpResponse(account: String) -> NKSession? {
        return nkCommonInstance.nksessions.filter({ $0.account == account }).first
    }

    public func deleteCookieStorageForAccount(_ account: String) {
        guard let nkSession = nkCommonInstance.nksessions.filter({ $0.account == account }).first else { return }

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
                self.nkCommonInstance.delegate?.networkReachabilityObserver(NKCommon.TypeReachability.unknown)
            case .notReachable:
                self.nkCommonInstance.delegate?.networkReachabilityObserver(NKCommon.TypeReachability.notReachable)
            case .reachable(.ethernetOrWiFi):
                self.nkCommonInstance.delegate?.networkReachabilityObserver(NKCommon.TypeReachability.reachableEthernetOrWiFi)
            case .reachable(.cellular):
                self.nkCommonInstance.delegate?.networkReachabilityObserver(NKCommon.TypeReachability.reachableCellular)
            }
        })
    }

    private func stopNetworkReachabilityObserver() {
        reachabilityManager?.stopListening()
    }
#endif
}
