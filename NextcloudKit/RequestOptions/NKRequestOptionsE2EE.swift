//
//  NKRequestOptionsE2EE.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 19.10.2022.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

@objcMembers
public class NKRequestOptionsE2EE: NSObject {
    let e2eToken: String?
    let e2eMetadata: String?
    let csr: String?
    let privateKey: String?

    public init(e2eToken: String? = nil, e2eMetadata: String? = nil, csr: String? = nil, privateKey: String? = nil) {
        self.e2eToken = e2eToken
        self.e2eMetadata = e2eMetadata
        self.csr = csr
        self.privateKey = privateKey
    }
}
