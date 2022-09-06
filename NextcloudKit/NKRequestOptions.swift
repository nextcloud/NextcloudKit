//
//  NKRequestOptions.swift
//  NextcloudKit
//
//  Created by Henrik Storch on 26.11.2021.
//  Copyright © 2022 Henrik Sorch. All rights reserved.
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
public class NKRequestOptions: NSObject {
    let endpoint: String?
    let customHeader: [String: String]?
    let customUserAgent: String?
    let contentType: String?
    let e2eToken: String?
    let queue: DispatchQueue

    public init(endpoint: String? = nil, customHeader: [String: String]? = nil, customUserAgent: String? = nil, contentType: String? = nil, e2eToken: String? = nil, queue: DispatchQueue = .main) {
        self.endpoint = endpoint
        self.customHeader = customHeader
        self.customUserAgent = customUserAgent
        self.contentType = contentType
        self.e2eToken = e2eToken
        self.queue = queue
    }
}
