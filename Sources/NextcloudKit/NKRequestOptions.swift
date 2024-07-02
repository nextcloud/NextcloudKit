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

public class NKRequestOptions: NSObject {
    var endpoint: String?
    var version: String?
    var customHeader: [String: String]?
    var customUserAgent: String?
    var contentType: String?
    var e2eToken: String?
    var timeout: TimeInterval
    var taskDescription: String?
    var removeProperties: [String]
    var queue: DispatchQueue

    public init(endpoint: String? = nil, 
                version: String? = nil,
                customHeader: [String: String]? = nil,
                customUserAgent: String? = nil,
                contentType: String? = nil,
                e2eToken: String? = nil,
                timeout: TimeInterval = 60,
                taskDescription: String? = nil,
                removeProperties: [String] = [],
                queue: DispatchQueue = .main) {

        self.endpoint = endpoint
        self.version = version
        self.customHeader = customHeader
        self.customUserAgent = customUserAgent
        self.contentType = contentType
        self.e2eToken = e2eToken
        self.timeout = timeout
        self.taskDescription = taskDescription
        self.removeProperties = removeProperties
        self.queue = queue
    }
}
