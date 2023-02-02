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
    let _endpoint: String?
    let _customHeader: [String: String]?
    let _customUserAgent: String?
    let _contentType: String?
    let _e2eToken: String?
    let _timeout: TimeInterval
    let _queue: DispatchQueue

    public var endpoint: String? {
        get {
            return _endpoint
        }
    }

    public var customHeader: [String: String]? {
        get {
            return _customHeader
        }
    }

    public var customUserAgent: String? {
        get {
            return _customUserAgent
        }
    }

    public var contentType: String? {
        get {
            return _contentType
        }
    }

    public var e2eToken: String? {
        get {
            return _e2eToken
        }
    }

    public var timeout: TimeInterval {
        get {
            return _timeout
        }
    }

    public var queue: DispatchQueue {
        get {
            return _queue
        }
    }

    public init(endpoint: String? = nil, customHeader: [String: String]? = nil, customUserAgent: String? = nil, contentType: String? = nil, e2eToken: String? = nil, timeout: TimeInterval = 60, queue: DispatchQueue = .main) {
        self._endpoint = endpoint
        self._customHeader = customHeader
        self._customUserAgent = customUserAgent
        self._contentType = contentType
        self._e2eToken = e2eToken
        self._timeout = timeout
        self._queue = queue
    }
}
