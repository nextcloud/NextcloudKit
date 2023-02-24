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

    let internalEndpoint: String?
    let internalCustomHeader: [String: String]?
    let internalCustomUserAgent: String?
    let internalContentType: String?
    let internalE2eToken: String?
    let internalTimeout: TimeInterval
    let internalQueue: DispatchQueue

    public var endpoint: String? {
        return internalEndpoint
    }

    public var customHeader: [String: String]? {
        return internalCustomHeader
    }

    public var customUserAgent: String? {
        return internalCustomUserAgent
    }

    public var contentType: String? {
        return internalContentType
    }

    public var e2eToken: String? {
        return internalE2eToken
    }

    public var timeout: TimeInterval {
        return internalTimeout
    }

    public var queue: DispatchQueue {
        return internalQueue
    }

    public init(endpoint: String? = nil, customHeader: [String: String]? = nil, customUserAgent: String? = nil, contentType: String? = nil, e2eToken: String? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main) {
        self.internalEndpoint = endpoint
        self.internalCustomHeader = customHeader
        self.internalCustomUserAgent = customUserAgent
        self.internalContentType = contentType
        self.internalE2eToken = e2eToken
        self.internalTimeout = timeout
        self.internalQueue = queue
    }
}
