// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Henrik Sorch
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

final public class NKRequestOptions: NSObject, Sendable {
    public let endpoint: String?
    public let version: String?
    internal(set) public var customHeader: [String: String]?
    public let customUserAgent: String?
    internal(set) public var contentType: String?
    public let e2eToken: String?
    internal(set) public var timeout: TimeInterval
    public let taskDescription: String?
    public let createProperties: [NKProperties]?
    public let removeProperties: [NKProperties]
    public let checkInterceptor: Bool
    public let paginate: Bool
    public let paginateToken: String?
    public let paginateOffset: Int?
    public let paginateCount: Int?
    public let queue: DispatchQueue

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
                checkInterceptor: Bool = true,
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
        self.checkInterceptor = checkInterceptor
        self.paginate = paginate
        self.paginateToken = paginateToken
        self.paginateOffset = paginateOffset
        self.paginateCount = paginateCount
        self.queue = queue
    }
}
