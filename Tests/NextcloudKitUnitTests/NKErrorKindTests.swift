// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Foundation
import SwiftyJSON
import Testing
@testable import NextcloudKit

/// Verifies that `NKError` classifies failures into a `Kind` and only passes on the share API's messages.
@Suite("NKError kind and server message")
struct NKErrorKindTests {
    static let urlErrorCases: [(Int, NKError.Kind)] = [
        (NSURLErrorNotConnectedToInternet, .offline),
        (NSURLErrorTimedOut, .timeout),
        (NSURLErrorCannotFindHost, .serverUnreachable),
        (NSURLErrorServerCertificateUntrusted, .secureConnection),
        (NSURLErrorUserAuthenticationRequired, .unauthorized),
        (NSURLErrorCannotParseResponse, .invalidResponse),
        (NSURLErrorCancelled, .cancelled),
        (NSURLErrorUnknown, .unknown)
    ]

    static let httpStatusCases: [(Int, NKError.Kind)] = [
        (400, .unknown),
        (401, .unauthorized),
        (403, .forbidden),
        (404, .notFound),
        (409, .conflict),
        (412, .conflict),
        (413, .tooLarge),
        (423, .locked),
        (429, .rateLimited),
        (500, .serverError),
        (502, .serverUnreachable),
        (503, .unavailable),
        (504, .timeout),
        (507, .quotaExceeded)
    ]

    static let ocsStatusCases: [(Int, NKError.Kind?)] = [
        (200, nil),
        (403, .forbidden),
        (500, .serverError),
        (997, .unauthorized)
    ]

    private static let davURL = URL(string: "https://cloud.example.com/remote.php/dav/files/alice/Documents")!
    private static let shareURL = URL(string: "https://cloud.example.com/ocs/v2.php/apps/files_sharing/api/v1/shares/42")!

    private func davErrorBody(exception: String, message: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
          <s:exception>\(exception)</s:exception>
          <s:message>\(message)</s:message>
        </d:error>
        """.utf8)
    }

    private func ocsErrorBody(statusCode: Int, message: String) -> Data {
        Data(#"{"ocs":{"meta":{"status":"failure","statuscode":\#(statusCode),"message":"\#(message)"},"data":[]}}"#.utf8)
    }

    private func responseError(url: URL = NKErrorKindTests.davURL, statusCode: Int, method: String, body: Data?) -> NKError {
        var request = URLRequest(url: url)
        request.httpMethod = method

        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
        let dataResponse = AFDataResponse<Data>(request: request, response: response, data: body, metrics: nil, serializationDuration: 0, result: .failure(.responseValidationFailed(reason: .unacceptableStatusCode(code: statusCode))))

        return NKError(error: dataResponse.error, afResponse: dataResponse, responseData: body)
    }

    @Test("Classifies URL loading errors", arguments: NKErrorKindTests.urlErrorCases)
    func urlErrors(code: Int, kind: NKError.Kind) {
        #expect(NKError(nsError: NSError(domain: NSURLErrorDomain, code: code)).kind == kind)
    }

    @Test("Classifies HTTP statuses without changing the description", arguments: NKErrorKindTests.httpStatusCases)
    func httpStatuses(statusCode: Int, kind: NKError.Kind) {
        let error = NKError(statusCode: statusCode, fallbackDescription: "Fallback")

        #expect(error.kind == kind)
        #expect(error.errorDescription.hasPrefix("\(statusCode): "))
    }

    @Test("Classifies OCS status codes, including OCS v1 ones", arguments: NKErrorKindTests.ocsStatusCases)
    func ocsStatusCodes(statusCode: Int, kind: NKError.Kind?) throws {
        let json = try JSON(data: ocsErrorBody(statusCode: statusCode, message: "Message"))

        #expect(NKError(rootJson: json, fallbackStatusCode: 200).kind == kind)
    }

    @Test("Uses the request method to tell WebDAV statuses apart")
    func requestMethod() {
        let body = davErrorBody(exception: "Sabre\\DAV\\Exception\\MethodNotAllowed", message: "The resource you tried to create already exists")

        #expect(responseError(statusCode: 405, method: "MKCOL", body: body).kind == .alreadyExists)
        #expect(responseError(statusCode: 405, method: "PROPFIND", body: body).kind == .unknown)
        #expect(responseError(statusCode: 412, method: "MOVE", body: body).kind == .alreadyExists)
        #expect(responseError(statusCode: 412, method: "COPY", body: body).kind == .alreadyExists)
        #expect(responseError(statusCode: 412, method: "PUT", body: body).kind == .conflict)
    }

    @Test("Keeps WebDAV messages in the logs only")
    func davMessage() {
        let error = responseError(statusCode: 409, method: "MKCOL", body: davErrorBody(exception: "Sabre\\DAV\\Exception\\Conflict", message: "Parent node does not exist"))

        #expect(error.kind == .conflict)
        #expect(error.userFriendlyServerMessage == nil)
        #expect(error.errorDescription == "Parent node does not exist")
    }

    @Test("Recognizes a rejected file or folder name")
    func invalidPath() {
        let body = davErrorBody(exception: "OCA\\DAV\\Connector\\Sabre\\Exception\\InvalidPath", message: "\"/\" is not allowed inside a file or folder name.")
        let error = responseError(statusCode: 400, method: "MKCOL", body: body)

        #expect(error.kind == .invalidName)
        #expect(error.userFriendlyServerMessage == nil)
    }

    @Test("Passes on the share API's messages")
    func shareAPIMessage() {
        let error = responseError(url: Self.shareURL, statusCode: 403, method: "PUT", body: ocsErrorBody(statusCode: 403, message: "Public upload disabled by the administrator"))

        #expect(error.kind == .forbidden)
        #expect(error.userFriendlyServerMessage == "Public upload disabled by the administrator")
    }

    @Test("Keeps the messages of other OCS APIs in the logs only", arguments: [
        "https://cloud.example.com/ocs/v2.php/apps/sharing/api/v1/share/abc",
        "https://cloud.example.com/ocs/v2.php/apps/files_sharing/api/v1/sharees"
    ])
    func otherOCSMessages(url: String) throws {
        let error = responseError(url: try #require(URL(string: url)), statusCode: 404, method: "GET", body: ocsErrorBody(statusCode: 404, message: "Share not found"))

        #expect(error.kind == .notFound)
        #expect(error.userFriendlyServerMessage == nil)
        #expect(error.errorDescription == "Share not found")
    }

    @Test("Derives the kind of explicit and preset errors")
    func explicitErrors() {
        #expect(NKError.success.kind == nil)
        #expect(NKError.cancelled.kind == .cancelled)
        #expect(NKError.unauthorizedError.kind == .unauthorized)
        #expect(NKError.forbiddenError.kind == .forbidden)
        #expect(NKError.unavailableError.kind == .unavailable)
        #expect(NKError.invalidData.kind == .invalidResponse)
        #expect(NKError.xmlError.kind == .invalidResponse)
        #expect(NKError.errorChunkNoEnoughMemory.kind == .localStorageFull)
        #expect(NKError(errorCode: -99999, errorDescription: "_internal_error_").kind == .unknown)
        #expect(NKError(errorCode: -3, errorDescription: "No space", kind: .localStorageFull).kind == .localStorageFull)
    }

    @Test("Classifies errors that do not come from a response")
    func otherErrors() {
        let decodingError = DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Broken"))

        #expect(NKError(error: decodingError).kind == .invalidResponse)
        #expect(NKError(error: CancellationError()).kind == .cancelled)
        #expect(NKError(error: AFError.explicitlyCancelled).kind == .cancelled)
        #expect(NKError(nsError: NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)).kind == .localStorageFull)
        #expect(NKError(error: NKError.forbiddenError).kind == .forbidden)
    }

    @Test("Classifies transport failures without a response")
    func transportFailure() {
        let dataResponse = AFDataResponse<Data>(request: URLRequest(url: Self.davURL), response: nil, data: nil, metrics: nil, serializationDuration: 0, result: .failure(.sessionTaskFailed(error: URLError(.notConnectedToInternet))))
        let error = NKError(error: dataResponse.error, afResponse: dataResponse)

        #expect(error.kind == .offline)
        #expect(error.errorCode == NSURLErrorNotConnectedToInternet)
    }

    @Test("Classifies stored error codes")
    func storedCodes() {
        #expect(NKError.Kind(code: 0) == nil)
        #expect(NKError.Kind(code: 507) == .quotaExceeded)
        #expect(NKError.Kind(code: NSURLErrorNotConnectedToInternet) == .offline)
        #expect(NKError.Kind(code: 997) == .unauthorized)
        #expect(NKError.Kind(code: 405, method: "MKCOL") == .alreadyExists)
    }

    @Test("Equality still compares only the code and the description")
    func equality() {
        #expect(NKError(errorCode: 404, errorDescription: "Gone", kind: .notFound) == NKError(errorCode: 404, errorDescription: "Gone", kind: .unknown))
    }
}
