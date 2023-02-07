//
//  NKShareAccounts.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 07/02/23.
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
import UIKit

@objc public class NKShareAccounts: NSObject {

    @objc public class NKDataAccountFile: NSObject {

        @objc public var url: String
        @objc public var user: String
        @objc public var alias: String?
        @objc public var avatar: String?

        @objc public init(withUrl url: String, user: String, alias: String? = nil, avatar: String? = nil) {
            self.url = url
            self.user = user
            self.alias = alias
            self.avatar = avatar
        }
    }

    internal struct Account: Codable {
        let url: String
        let user: String
        let alias: String?
        let avatar: String?
    }

    internal struct Apps: Codable {
        let apps: [String: [Account]]?
    }

    @objc func putShareAccounts(at url: URL, app: String, dataAccounts: [NKDataAccountFile]) -> Error? {

        var apps: [String : [Account]] = [:]
        var accounts: [Account] = []

        for dataAccount in dataAccounts {
            let account = Account(url: dataAccount.url, user: dataAccount.user, alias: dataAccount.alias, avatar: dataAccount.avatar)
            accounts.append(account)
        }
        apps[app] = accounts

        // Decode
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONDecoder().decode(Apps.self, from: data)
            if let appsDecoder = json.apps {
                let otherApps = appsDecoder.filter({ $0.key != app })
                apps.merge(otherApps){(current, _) in current}
            }
        } catch { }

        // Encode
        do {
            let data = try JSONEncoder().encode(Apps(apps: apps))
            try data.write(to: url)
        } catch let error {
            return error
        }
        return nil
    }

    @objc func getShareAccount(at url: URL, application: UIApplication?) -> [NKDataAccountFile]? {

        var dataAccounts: [NKDataAccountFile] = []

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONDecoder().decode(Apps.self, from: data)
            if let appsDecoder = json.apps {
                for appDecoder in appsDecoder {
                    let app = appDecoder.key
                    let accounts = appDecoder.value
                    if let url = URL(string: app + "://"), let application = application, application.canOpenURL(url) {
                        for account in accounts {
                            if dataAccounts.first(where: { $0.url == account.url && $0.user == account.user }) == nil {
                                let account = NKDataAccountFile(withUrl: account.url, user: account.user, alias: account.alias, avatar: account.avatar)
                                dataAccounts.append(account)
                            }
                        }
                    }
                }
            }
        } catch { }

        return dataAccounts.isEmpty ? nil : dataAccounts
    }
}
