// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Henrik Sorch
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
    var createProperties: [NKProperties]?
    var removeProperties: [NKProperties]
    var checkUnauthorized: Bool?
    var paginate: Bool
    var paginateToken: String?
    var paginateOffset: Int?
    var paginateCount: Int?
    var queue: DispatchQueue

    public init(endpoint: String? = nil,
                version: String? = nil,
                customHeader: [String: String]? = nil,
                customUserAgent: String? = nil,
                contentType: String? = nil,
                e2eToken: String? = nil,
                timeout: TimeInterval = 60,
                taskDescription: String? = nil,
                createProperties: [NKProperties]? = nil,
                removeProperties: [NKProperties] = [],
                checkUnauthorized: Bool? = nil,
                paginate: Bool = false,
                paginateToken: String? = nil,
                paginateOffset: Int? = nil,
                paginateCount: Int? = nil,
                queue: DispatchQueue = .main) {

        self.endpoint = endpoint
        self.version = version
        self.customHeader = customHeader
        self.customUserAgent = customUserAgent
        self.contentType = contentType
        self.e2eToken = e2eToken
        self.timeout = timeout
        self.taskDescription = taskDescription
        self.createProperties = createProperties
        self.removeProperties = removeProperties
        self.checkUnauthorized = checkUnauthorized
        self.paginate = paginate
        self.paginateToken = paginateToken
        self.paginateOffset = paginateOffset
        self.paginateCount = paginateCount
        self.queue = queue
    }
}
