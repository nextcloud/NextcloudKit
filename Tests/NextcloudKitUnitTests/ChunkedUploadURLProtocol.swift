// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

final class ChunkedUploadURLProtocol: URLProtocol {
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

        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
