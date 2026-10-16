// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

final class ChunkedUploadURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var handlers: [String: @Sendable (ChunkedUploadURLProtocol) -> Bool] = [:]

    static func setHandler(forHost host: String, handler: (@Sendable (ChunkedUploadURLProtocol) -> Bool)?) {
        lock.lock()
        defer { lock.unlock() }
        handlers[host] = handler
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host.hasPrefix("assembly-") && host.hasSuffix(".test")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.lock.lock()
        let handler = Self.handlers[url.host ?? ""]
        Self.lock.unlock()
        if handler?(self) == true {
            return
        }

        let statusCode: Int
        var headers: [String: String] = [:]
        switch request.httpMethod {
        case "PROPFIND":
            statusCode = 404
        case "MKCOL", "PUT":
            statusCode = 201
        case "MOVE":
            let requestedStatus = Int(url.host?.split(separator: "-").last?.split(separator: ".").first ?? "") ?? 500
            if requestedStatus == 412 {
                // Simulate an occupied destination: the MOVE succeeds only when overwriting is allowed.
                switch request.value(forHTTPHeaderField: "Overwrite") {
                case "F": statusCode = 412
                case "T": statusCode = 201
                default: statusCode = 400
                }
            } else {
                statusCode = requestedStatus
            }
            if statusCode == 201 {
                headers = ["OC-FileID": "assembled-file-id", "OC-ETag": "assembled-etag"]
            }
        default:
            statusCode = 500
        }

        respond(status: statusCode, headers: headers)
    }

    func respond(status: Int, headers: [String: String] = [:], data: Data = Data()) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
