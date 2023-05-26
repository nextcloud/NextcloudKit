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
#if os(iOS)
import UIKit

@objc public class NKShareAccounts: NSObject {

    @objc public class DataAccounts: NSObject {

        @objc public var url: String
        @objc public var user: String
        @objc public var name: String?
        @objc public var image: UIImage?

        @objc public init(withUrl url: String, user: String, name: String? = nil, image: UIImage? = nil) {
            self.url = url
            self.user = user
            self.name = name
            self.image = image
        }
    }

    internal struct Account: Codable {
        let url: String
        let user: String
        let name: String?
    }

    internal struct Apps: Codable {
        let apps: [String: [Account]]?
    }

    internal let fileName: String = "accounts.json"
    internal let directoryAccounts: String = "Library/Application Support/NextcloudAccounts"

    /// - Parameters:
    ///     - directory: the group directory of share the accounts (group.com.nextcloud.apps), use the  func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? // Available for OS X in 10.8.3.
    ///     - app: the name of app
    ///     - dataAccounts: the accounts data
    @objc public func putShareAccounts(at directory: URL, app: String, dataAccounts: [DataAccounts]) -> Error? {

        var apps: [String: [Account]] = [:]
        var accounts: [Account] = []
        let url = directory.appendingPathComponent(directoryAccounts + "/" + fileName)

        do {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent(directoryAccounts), withIntermediateDirectories: true)
        } catch { }

        // Add data account and image
        for dataAccount in dataAccounts {
            if let image = dataAccount.image {
                do {
                    let filePathImage = getFileNamePathImage(at: directory, url: dataAccount.url, user: dataAccount.user)
                    try image.pngData()?.write(to: filePathImage, options: .atomic)
                } catch { }
            }
            let account = Account(url: dataAccount.url, user: dataAccount.user, name: dataAccount.name)
            accounts.append(account)
        }
        apps[app] = accounts

        // Decode
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONDecoder().decode(Apps.self, from: data)
            if let appsDecoder = json.apps {
                let otherApps = appsDecoder.filter({ $0.key != app })
                apps.merge(otherApps) { current, _ in current}
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

    /// - Parameters:
    ///     - directory: the group directory of share the accounts (group.com.nextcloud.apps), use the  func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? // Available for OS X in 10.8.3.
    ///     - application: the UIApplication used for verify if the app(s) is still installed
    @objc public func getShareAccount(at directory: URL, application: UIApplication) -> [DataAccounts]? {

        var dataAccounts: [DataAccounts] = []
        let url = directory.appendingPathComponent(directoryAccounts + "/" + fileName)

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONDecoder().decode(Apps.self, from: data)
            if let appsDecoder = json.apps {
                for appDecoder in appsDecoder {
                    let app = appDecoder.key
                    let accounts = appDecoder.value
                    if let url = URL(string: app + "://"), application.canOpenURL(url) {
                        for account in accounts {
                            if dataAccounts.first(where: { $0.url == account.url && $0.user == account.user }) == nil {
                                let filePathImage = getFileNamePathImage(at: directory, url: account.url, user: account.user)
                                let image = UIImage(contentsOfFile: filePathImage.path)
                                let account = DataAccounts(withUrl: account.url, user: account.user, name: account.name, image: image)
                                dataAccounts.append(account)
                            }
                        }
                    }
                }
            }
        } catch { }

        return dataAccounts.isEmpty ? nil : dataAccounts
    }

    private func getFileNamePathImage(at directory: URL, url: String, user: String) -> URL {

        let userBaseUrl = user + "-" + (URL(string: url)?.host ?? "")
        let fileName = userBaseUrl + "-\(user).png"
        return directory.appendingPathComponent(directoryAccounts + "/" + fileName)
    }
}
#endif
