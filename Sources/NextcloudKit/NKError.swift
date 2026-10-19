// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Henrik Sorch
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON
import SwiftyXMLParser

typealias OCSPath = Array<String>

protocol DataSubscriptable {
    subscript(path: OCSPath) -> Self { get }
}

extension JSON: DataSubscriptable {
    subscript(path: OCSPath) -> JSON {
        return self[path as [JSONSubscriptType]]
    }
}

extension XML.Accessor: DataSubscriptable {
    subscript(path: OCSPath) -> XML.Accessor {
        return self[path as [XMLSubscriptType]]
    }
}

extension OCSPath {
    static var ocsMetaCode: Self { ["ocs", "meta", "statuscode"] }
    static var ocsMetaMsg: Self { ["ocs", "meta", "message"] }
    static var ocsDataMsg: Self { ["ocs", "data", "message"] }
    static var ocsXMLMsg: Self { ["d:error", "s:message"] }
    static var davException: Self { ["d:error", "s:exception"] }
}

public struct NKError: Error, Equatable, Sendable {
    static let internalError = -9999

    public let errorCode: Int
    public let errorDescription: String
    public let error: Error
    public let responseData: Data?

    /// What went wrong, for choosing the message shown to users; `nil` for ``success``.
    public let kind: Kind?
    /// The OCS message the server sent with the error.
    let serverMessage: String?
    /// The URL path of the request that failed, when known.
    private(set) var requestPath: String?

    public static let urlError = NKError(errorCode: NSURLErrorBadURL, errorDescription: NSLocalizedString("Invalid server URL", bundle: .module, comment: "Error message when the server address is not a valid URL."))
    public static let invalidResponseError = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: NSLocalizedString("Invalid response", bundle: .module, comment: "Error message when the server's response is not valid."))
    public static let xmlError = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: NSLocalizedString("Invalid response, error decoding XML", bundle: .module, comment: "Error message when the server's XML response cannot be read."))
    public static let invalidDate = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: NSLocalizedString("Invalid date format", bundle: .module, comment: "Error message when a date in the server's response cannot be read."))
    public static let invalidData = NKError(errorCode: NSURLErrorCannotDecodeContentData, errorDescription: NSLocalizedString("Invalid data format", bundle: .module, comment: "Error message when data in the server's response cannot be read."))
    public static let unauthorizedError = NKError(errorCode: 401, errorDescription: NSLocalizedString("Unauthorized", bundle: .module, comment: "Error message when the server rejects the login (HTTP 401)."))
    public static let unavailableError = NKError(errorCode: 503, errorDescription: NSLocalizedString("Unavailable", bundle: .module, comment: "Error message when the server is unavailable."))
    public static let forbiddenError = NKError(errorCode: 403, errorDescription: NSLocalizedString("Forbidden", bundle: .module, comment: "Error message when the server forbids the request."))
    public static let cancelled = NKError(errorCode: -999, errorDescription: NSLocalizedString("Cancelled", bundle: .module, comment: "Error message when a request was cancelled."))

    public static let errorChunkFileNull = NKError(errorCode: -9994, errorDescription: NSLocalizedString("File not found", bundle: .module, comment: "Error message when the file to upload in chunks cannot be found."))
    public static let errorChunkFilesEmpty = NKError(errorCode: -9995, errorDescription: NSLocalizedString("Files not found", bundle: .module, comment: "Error message when a chunked upload has no chunks to upload."))
    public static let errorChunkCreateFolder = NKError(errorCode: -9996, errorDescription: NSLocalizedString("Create folder error", bundle: .module, comment: "Error message when the folder for a chunked upload cannot be created."))
    public static let errorChunkMoveFile = NKError(errorCode: -9997, errorDescription: NSLocalizedString("Move file error", bundle: .module, comment: "Error message when the uploaded chunks cannot be assembled into the file."))
    public static let errorChunkNoEnoughMemory = NKError(errorCode: -9998, errorDescription: NSLocalizedString("Not enough memory", bundle: .module, comment: "Error message when the device lacks the space to split a file into chunks."), kind: .localStorageFull)

    public static let success = NKError(errorCode: 0, errorDescription: "")

    /// The share API's error message, which Nextcloud writes for users. Other server texts are technical.
    public var userFriendlyServerMessage: String? {
        guard requestPath?.contains("/apps/files_sharing/api/v1/shares") == true else { return nil }

        return serverMessage
    }

    /// Returns a localized user-facing description for a known error code.
    ///
    /// - Parameter code: The HTTP, URL loading, WebDAV, OCS, or internal error code.
    /// - Returns: A localized description when the code is known, otherwise `nil`.
    public static func getErrorDescription(for code: Int) -> String? {
        switch code {
        case -9999:
            return NSLocalizedString("Internal error", bundle: .module, comment: "Error message for an internal error in the app.")

        case -1001:
            return NSLocalizedString("Time out", bundle: .module, comment: "Error message when a request timed out.")

        case -1004:
            return NSLocalizedString("The server appears to be down", bundle: .module, comment: "Error message when the server cannot be reached.")

        case -1005:
            return NSLocalizedString("It is not possible to connect to the server at this time", bundle: .module, comment: "Error message when the connection to the server failed.")

        case -1009:
            return NSLocalizedString("Server connection error", bundle: .module, comment: "Error message when the device has no internet connection.")

        case -1011:
            return NSLocalizedString("Generic error", bundle: .module, comment: "Error message when no more specific description is available.")

        case -1012:
            return NSLocalizedString("It is not possible to connect to the server at this time", bundle: .module, comment: "Error message when the connection to the server failed.")

        case -1013:
            return NSLocalizedString("User authentication required", bundle: .module, comment: "Error message when the server requires a login.")

        case -1200:
            return NSLocalizedString("Connection SSL error, try again", bundle: .module, comment: "Error message when a secure connection to the server failed.")

        case -1202:
            return NSLocalizedString("The certificate for this server is invalid", bundle: .module, comment: "Error message when the server's certificate is not trusted.")

        case 0:
            return ""

        case 101:
            return NSLocalizedString("The name contains at least one invalid character", bundle: .module, comment: "Error message when the server rejects a name because of invalid characters.")

        case 200:
            return NSLocalizedString("Transfer stopped", bundle: .module, comment: "Error message when a transfer was stopped.")

        case 207:
            return NSLocalizedString("WebDAV multistatus", bundle: .module, comment: "Error message for a WebDAV Multi-Status response (HTTP 207).")

        case 304:
            return NSLocalizedString("Resource not modified", bundle: .module, comment: "Error message when the resource was not modified (HTTP 304).")

        case 400:
            return NSLocalizedString("Bad request", bundle: .module, comment: "Error message when the server cannot process the request (HTTP 400).")

        case 401:
            return NSLocalizedString("Unauthorized", bundle: .module, comment: "Error message when the server rejects the login (HTTP 401).")

        case 403:
            return NSLocalizedString("You don't have permission to complete the operation", bundle: .module, comment: "Error message when the server forbids the operation (HTTP 403).")

        case 404:
            return NSLocalizedString("The requested resource could not be found", bundle: .module, comment: "Error message when the file, folder or resource does not exist (HTTP 404).")

        case 405:
            return NSLocalizedString("The requested method is not supported", bundle: .module, comment: "Error message when the server doesn't allow the request method (HTTP 405).")

        case 408:
            return NSLocalizedString("Request timeout", bundle: .module, comment: "Error message when the server timed out waiting for the request (HTTP 408).")

        case 409:
            return NSLocalizedString("The request could not be completed due to a conflict with the current state of the resource", bundle: .module, comment: "Error message when the request conflicts with the current state on the server (HTTP 409).")

        case 412:
            return NSLocalizedString("The server does not meet one of the preconditions of the request", bundle: .module, comment: "Error message when a precondition of the request failed (HTTP 412).")

        case 413:
            return NSLocalizedString("The file is too large", bundle: .module, comment: "Error message when the file is too large for the server (HTTP 413).")

        case 417:
            return NSLocalizedString("Expectation failed", bundle: .module, comment: "Error message when the server cannot meet the request's expectation (HTTP 417).")

        case 423:
            return NSLocalizedString("WebDAV Locked: Trying to access locked resource", bundle: .module, comment: "Error message when the file is locked (HTTP 423).")

        case 429:
            return NSLocalizedString("Too many requests", bundle: .module, comment: "Error message when the server rate-limits the requests (HTTP 429).")

        case 500:
            return NSLocalizedString("Internal server error", bundle: .module, comment: "Error message when the server ran into an error (HTTP 500).")

        case 502:
            return NSLocalizedString("Bad gateway", bundle: .module, comment: "Error message when a proxy got an invalid response from the server (HTTP 502).")

        case 503:
            return NSLocalizedString("Server is currently in maintenance mode", bundle: .module, comment: "Error message when the server is in maintenance mode (HTTP 503).")

        case 504:
            return NSLocalizedString("Gateway timeout", bundle: .module, comment: "Error message when a proxy timed out waiting for the server (HTTP 504).")

        case 507:
            return NSLocalizedString("Storage quota is reached", bundle: .module, comment: "Error message when the account's storage quota is used up (HTTP 507).")

        case NSURLErrorCannotDecodeContentData:
            return NSLocalizedString("Invalid data format", bundle: .module, comment: "Error message when data in the server's response cannot be read.")

        default:
            return nil
        }
    }

    /// Returns a clean fallback description for an HTTP status code.
    ///
    /// This method intentionally avoids `HTTPURLResponse.description`, because that value contains
    /// the full response dump, including URL and headers, and is not suitable for UI.
    ///
    /// - Parameter statusCode: The HTTP status code.
    /// - Returns: A clean fallback description.
    private static func httpFallbackDescription(for statusCode: Int) -> String {
        let description = HTTPURLResponse.localizedString(forStatusCode: statusCode)

        if description.isEmpty {
            return NSLocalizedString("Generic error", bundle: .module, comment: "Error message when no more specific description is available.")
        }

        return description
    }

    private static func firstNonEmpty(_ candidates: String?...) -> String? {
        candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    /// Creates an `NKError` from an explicit code and description.
    ///
    /// - Parameters:
    ///   - errorCode: The error code.
    ///   - errorDescription: The user-facing error description.
    ///   - responseData: Optional raw response data associated with the error.
    ///   - kind: The kind of failure; derived from `errorCode` when `nil`.
    public init(errorCode: Int = 0, errorDescription: String = "", responseData: Data? = nil, kind: Kind? = nil) {
        self.errorCode = errorCode
        self.errorDescription = errorDescription
        self.error = NSError(
            domain: NSCocoaErrorDomain,
            code: self.errorCode,
            userInfo: [NSLocalizedDescriptionKey: self.errorDescription]
        )
        self.responseData = responseData
        self.kind = kind ?? Kind(code: errorCode)
        self.serverMessage = nil
    }

    /// Creates an `NKError` from a generic Swift `Error`.
    ///
    /// - Parameters:
    ///   - error: The source error.
    ///   - responseData: Optional raw response data associated with the error.
    public init(error: Error, responseData: Data? = nil) {
        self.errorCode = error._code
        self.errorDescription = error.localizedDescription
        self.error = error
        self.responseData = responseData
        self.kind = Kind(error: error)
        self.serverMessage = nil
    }

    /// Creates an `NKError` from an `NSError`.
    ///
    /// - Parameters:
    ///   - nsError: The source `NSError`.
    ///   - responseData: Optional raw response data associated with the error.
    public init(nsError: NSError, responseData: Data? = nil) {
        self.errorCode = nsError.code
        self.errorDescription = nsError.localizedDescription
        self.error = nsError
        self.responseData = responseData
        self.kind = Kind(error: nsError)
        self.serverMessage = nil
    }

    /// Creates an `NKError` from an OCS JSON response.
    ///
    /// - Parameters:
    ///   - rootJson: The parsed JSON response.
    ///   - fallbackStatusCode: The fallback HTTP status code used when the OCS status code is missing.
    ///   - responseData: Optional raw response data associated with the error.
    public init(rootJson: JSON, fallbackStatusCode: Int?, responseData: Data? = nil) {
        let statuscode = rootJson[.ocsMetaCode].int ?? fallbackStatusCode ?? NSURLErrorCannotDecodeContentData
        errorCode = 200..<300 ~= statuscode ? 0 : statuscode

        if let dataMsg = rootJson[.ocsDataMsg].string {
            errorDescription = dataMsg
        } else if let metaMsg = rootJson[.ocsMetaMsg].string {
            errorDescription = metaMsg
        } else {
            errorDescription = NKError.getErrorDescription(for: statuscode) ?? NKError.httpFallbackDescription(for: statuscode)
        }

        self.responseData = responseData
        self.error = NSError(
            domain: NSCocoaErrorDomain,
            code: self.errorCode,
            userInfo: [NSLocalizedDescriptionKey: self.errorDescription]
        )
        self.kind = errorCode == 0 ? nil : Kind(code: statuscode)
        self.serverMessage = NKError.firstNonEmpty(rootJson[.ocsDataMsg].string, rootJson[.ocsMetaMsg].string)
    }

    /// Creates an `NKError` from an HTTP status code.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code.
    ///   - fallbackDescription: A clean fallback description used when the status code is unknown.
    ///   - responseData: Optional raw response data associated with the error.
    public init(statusCode: Int, fallbackDescription: String, responseData: Data? = nil) {
        self.errorCode = statusCode

        let description = NKError.getErrorDescription(for: statusCode) ?? fallbackDescription
        self.errorDescription = "\(statusCode): \(description)"

        self.error = NSError(
            domain: NSCocoaErrorDomain,
            code: self.errorCode,
            userInfo: [NSLocalizedDescriptionKey: self.errorDescription]
        )

        self.responseData = responseData
        self.kind = Kind(code: statusCode)
        self.serverMessage = nil
    }

    /// Creates an `NKError` from an HTTP response.
    ///
    /// - Parameter httpResponse: The source HTTP response.
    init(httpResponse: HTTPURLResponse) {
        self.init(
            statusCode: httpResponse.statusCode,
            fallbackDescription: Self.httpFallbackDescription(for: httpResponse.statusCode)
        )
    }

    /// Creates an `NKError` from an OCS or WebDAV XML response.
    ///
    /// - Parameters:
    ///   - xmlData: The raw XML response data.
    ///   - fallbackStatusCode: The fallback HTTP status code used when the OCS status code is missing.
    ///   - method: The HTTP method of the request, which tells some WebDAV statuses apart.
    ///   - responseData: Optional raw response data associated with the error.
    init(xmlData: Data, fallbackStatusCode: Int? = nil, method: String? = nil, responseData: Data? = nil) {
        let xml = XML.parse(xmlData)
        let statuscode = xml[.ocsMetaCode].int ?? fallbackStatusCode ?? NSURLErrorCannotDecodeContentData
        errorCode = 200..<300 ~= statuscode ? 0 : statuscode

        if let dataMsg = xml[.ocsDataMsg].text {
            errorDescription = dataMsg
        } else if let metaMsg = xml[.ocsMetaMsg].text {
            errorDescription = metaMsg
        } else if let metaMsg = xml[.ocsXMLMsg].text {
            errorDescription = metaMsg
        } else {
            errorDescription = NKError.getErrorDescription(for: statuscode) ?? NKError.httpFallbackDescription(for: statuscode)
        }

        self.responseData = responseData
        self.error = NSError(
            domain: NSCocoaErrorDomain,
            code: self.errorCode,
            userInfo: [NSLocalizedDescriptionKey: self.errorDescription]
        )
        self.kind = errorCode == 0 ? nil : Kind(davException: xml[.davException].text) ?? Kind(code: statuscode, method: method)
        self.serverMessage = nil
    }

    /// Creates an `NKError` from an Alamofire response and optional Alamofire error.
    ///
    /// - Parameters:
    ///   - error: The Alamofire error, if available.
    ///   - afResponse: The Alamofire response.
    ///   - responseData: Optional raw response data associated with the error.
    public init<T: AFResponse>(error: AFError?, afResponse: T, responseData: Data? = nil) {
        let dataResponse = afResponse as? Alamofire.DataResponse<T.Success, T.Failure>

        if let errorCode = afResponse.response?.statusCode {
            if let errorData = dataResponse?.data {
                if let errorJson = try? JSON(data: errorData) {
                    self.init(rootJson: errorJson, fallbackStatusCode: errorCode, responseData: responseData)
                } else {
                    self.init(xmlData: errorData, fallbackStatusCode: errorCode, method: dataResponse?.request?.httpMethod, responseData: responseData)
                }
            } else {
                self.init(
                    statusCode: errorCode,
                    fallbackDescription: Self.httpFallbackDescription(for: errorCode),
                    responseData: responseData
                )
            }

        } else if let error = error {
            switch error {
            case .createUploadableFailed(let error as NSError):
                self.init(nsError: error, responseData: responseData)

            case .createURLRequestFailed(let error as NSError):
                self.init(nsError: error, responseData: responseData)

            case .requestAdaptationFailed(let error as NSError):
                self.init(nsError: error, responseData: responseData)

            case .sessionInvalidated(let error as NSError):
                self.init(nsError: error, responseData: responseData)

            case .sessionTaskFailed(let error as NSError):
                self.init(nsError: error, responseData: responseData)

            default:
                self.init(error: error, responseData: responseData)
            }
        } else {
            self.init(errorCode: 0, errorDescription: "", responseData: responseData)
        }

        requestPath = dataResponse?.request?.url?.path
    }

    public static func == (lhs: NKError, rhs: NKError) -> Bool {
        return lhs.errorCode == rhs.errorCode && lhs.errorDescription == rhs.errorDescription
    }

    public static func == (lhs: NKError, rhs: NKError?) -> Bool {
        if let rhs {
            return lhs == rhs
        }

        return false
    }
}

public protocol AFResponse {
    associatedtype Failure: Error
    associatedtype Success

    var response: HTTPURLResponse? { get }
    var error: Failure? { get }
}

extension AFDownloadResponse: AFResponse { }
extension AFDataResponse: AFResponse { }
