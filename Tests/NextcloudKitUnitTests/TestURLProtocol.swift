// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

final class TestURLProtocol: URLProtocol {
    struct Reply {
        let status: Int
        let data: Data
        let headers: [String: String]
    }

    private static let lock = NSLock()
    private static var reply: Reply?
    private static var recordedRequests: [URLRequest] = []

    static func setReply(status: Int, data: Data, headers: [String: String] = [:]) {
        lock.lock()
        reply = Reply(status: status, data: data, headers: headers)
        recordedRequests = []
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        reply = nil
        recordedRequests = []
        lock.unlock()
    }

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.recordedRequests.append(request)
        let reply = Self.reply
        Self.lock.unlock()

        guard let reply, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
