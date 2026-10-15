// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Foundation
import SwiftyJSON
import Testing
@testable import NextcloudKit

/// Verifies that `NKError` classifies failures into a `Kind` and keeps the raw server details apart.
@Suite("NKError kind and server details")
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

    private let davURL = URL(string: "https://cloud.example.com/remote.php/dav/files/alice/Documents")!

    private func davErrorBody(exception: String, message: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
          <s:exception>\(exception)</s:exception>
          <s:message>\(message)</s:message>
        </d:error>
        """.utf8)
    }

    private func responseError(statusCode: Int, method: String, body: Data?) -> NKError {
        var request = URLRequest(url: davURL)
        request.httpMethod = method

        let response = HTTPURLResponse(url: davURL, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
        let dataResponse = AFDataResponse<Data>(request: request, response: response, data: body, metrics: nil, serializationDuration: 0, result: .failure(.responseValidationFailed(reason: .unacceptableStatusCode(code: statusCode))))

        return NKError(error: dataResponse.error, afResponse: dataResponse, responseData: body)
    }

    @Test("Classifies URL loading errors", arguments: NKErrorKindTests.urlErrorCases)
    func urlErrors(code: Int, kind: NKError.Kind) {
        let error = NKError(nsError: NSError(domain: NSURLErrorDomain, code: code))

        #expect(error.kind == kind)
        #expect(error.httpStatusCode == nil)
    }

    @Test("Classifies HTTP statuses without changing the description", arguments: NKErrorKindTests.httpStatusCases)
    func httpStatuses(statusCode: Int, kind: NKError.Kind) {
        let error = NKError(statusCode: statusCode, fallbackDescription: "Fallback")

        #expect(error.kind == kind)
        #expect(error.httpStatusCode == statusCode)
        #expect(error.errorDescription.hasPrefix("\(statusCode): "))
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

    @Test("Reads the WebDAV exception and message, which stay out of the UI")
    func davDetails() {
        let error = responseError(statusCode: 409, method: "MKCOL", body: davErrorBody(exception: "Sabre\\DAV\\Exception\\Conflict", message: "Parent node does not exist"))

        #expect(error.kind == .conflict)
        #expect(error.httpStatusCode == 409)
        #expect(error.ocsStatusCode == nil)
        #expect(error.davException == "Sabre\\DAV\\Exception\\Conflict")
        #expect(error.serverMessage == "Parent node does not exist")
        #expect(error.userFacingServerMessage == nil)
        #expect(error.errorDescription == "Parent node does not exist")
    }

    @Test("Treats WebDAV file name rule violations as user-facing")
    func invalidPathIsUserFacing() {
        let message = "\"/\" is not allowed inside a file or folder name."
        let error = responseError(statusCode: 400, method: "MKCOL", body: davErrorBody(exception: "OCA\\DAV\\Connector\\Sabre\\Exception\\InvalidPath", message: message))

        #expect(error.kind == .unknown)
        #expect(error.userFacingServerMessage == message)
    }

    @Test("Reads the OCS status code and message")
    func ocsDetails() throws {
        let json = try JSON(data: Data(#"{"ocs":{"meta":{"status":"failure","statuscode":403,"message":"Group sharing is disabled by the administrator"},"data":[]}}"#.utf8))
        let error = NKError(rootJson: json, fallbackStatusCode: 403)

        #expect(error.kind == .forbidden)
        #expect(error.httpStatusCode == 403)
        #expect(error.ocsStatusCode == 403)
        #expect(error.serverMessage == "Group sharing is disabled by the administrator")
        #expect(error.userFacingServerMessage == "Group sharing is disabled by the administrator")
        #expect(error.errorDescription == "Group sharing is disabled by the administrator")
    }

    @Test("Takes the message from a string `ocs.data`, as the unified sharing API sends it")
    func ocsDataMessage() {
        let body = Data(#"{"ocs":{"meta":{"statuscode":400,"message":""},"data":"Password needs to be at least 10 characters long"}}"#.utf8)
        let error = responseError(statusCode: 400, method: "POST", body: body)

        #expect(error.ocsStatusCode == 400)
        #expect(error.userFacingServerMessage == "Password needs to be at least 10 characters long")
    }

    @Test("Keeps OCS server errors out of the UI")
    func ocsServerError() throws {
        let json = try JSON(data: Data(#"{"ocs":{"meta":{"statuscode":500,"message":"Internal error"},"data":[]}}"#.utf8))
        let error = NKError(rootJson: json, fallbackStatusCode: 500)

        #expect(error.kind == .serverError)
        #expect(error.serverMessage == "Internal error")
        #expect(error.userFacingServerMessage == nil)
    }

    @Test("Maps OCS v1 status codes")
    func ocsV1StatusCodes() throws {
        let json = try JSON(data: Data(#"{"ocs":{"meta":{"statuscode":997,"message":"Current user is not logged in"},"data":[]}}"#.utf8))
        let error = NKError(rootJson: json, fallbackStatusCode: 200)

        #expect(error.kind == .unauthorized)
        #expect(error.userFacingServerMessage == nil)
    }

    @Test("A successful OCS response has no kind")
    func ocsSuccess() throws {
        let json = try JSON(data: Data(#"{"ocs":{"meta":{"statuscode":200,"message":"OK"},"data":[]}}"#.utf8))
        let error = NKError(rootJson: json, fallbackStatusCode: 200)

        #expect(error.errorCode == 0)
        #expect(error.kind == nil)
    }

    @Test("Reads server details from the response data of explicit errors")
    func explicitErrorWithResponseData() {
        let body = Data(#"{"ocs":{"meta":{"statuscode":404},"data":"Share not found"}}"#.utf8)
        let error = NKError(errorCode: 404, errorDescription: "Share not found", responseData: body)

        #expect(error.kind == .notFound)
        #expect(error.ocsStatusCode == 404)
        #expect(error.userFacingServerMessage == "Share not found")
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
        let dataResponse = AFDataResponse<Data>(request: URLRequest(url: davURL), response: nil, data: nil, metrics: nil, serializationDuration: 0, result: .failure(.sessionTaskFailed(error: URLError(.notConnectedToInternet))))
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
