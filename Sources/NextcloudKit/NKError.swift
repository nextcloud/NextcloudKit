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
    static var ocsData: Self { ["ocs", "data"] }
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
    private let serverMessage: String?
    /// The URL path of the request that failed, when known.
    private var requestPath: String?

    public static let urlError = NKError(errorCode: NSURLErrorBadURL, errorDescription: "Invalid server URL")
    public static let invalidResponseError = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: "Invalid response")
    public static let xmlError = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: "Invalid response, error decoding XML")
    public static let invalidDate = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: "Invalid date format")
    public static let invalidData = NKError(errorCode: NSURLErrorCannotDecodeContentData, errorDescription: "Invalid data format")
    public static let unauthorizedError = NKError(errorCode: 401, errorDescription: "Unauthorized")
    public static let unavailableError = NKError(errorCode: 503, errorDescription: "Unavailable")
    public static let forbiddenError = NKError(errorCode: 403, errorDescription: "Forbidden")
    public static let cancelled = NKError(errorCode: -999, errorDescription: "Cancelled")

    public static let errorChunkFileNull = NKError(errorCode: -9994, errorDescription: "File not found")
    public static let errorChunkFilesEmpty = NKError(errorCode: -9995, errorDescription: "Files not found")
    public static let errorChunkCreateFolder = NKError(errorCode: -9996, errorDescription: "Create folder error")
    public static let errorChunkMoveFile = NKError(errorCode: -9997, errorDescription: "Move file error")
    public static let errorChunkNoEnoughMemory = NKError(errorCode: -9998, errorDescription: "Not enough memory", kind: .localStorageFull)

    public static let success = NKError(errorCode: 0, errorDescription: "")

    /// The server's message where Nextcloud writes it for users: the share API and unified sharing's property updates.
    /// Other server texts are technical.
    public var userFriendlyServerMessage: String? {
        guard let requestPath else { return nil }

        let isShareAPI = requestPath.contains("/apps/files_sharing/api/v1/shares")
        let isUnifiedShareProperty = requestPath.contains("/apps/sharing/api/v1/share/") && requestPath.hasSuffix("/property")

        return isShareAPI || isUnifiedShareProperty ? serverMessage : nil
    }

    /// Returns the English description of a known error code, for logs.
    ///
    /// - Parameter code: The HTTP, URL loading, WebDAV, OCS, or internal error code.
    /// - Returns: A description when the code is known, otherwise `nil`.
    public static func getErrorDescription(for code: Int) -> String? {
        switch code {
        case -9999:
            return "Internal error"

        case -1001:
            return "Time out"

        case -1004:
            return "The server appears to be down"

        case -1005:
            return "It is not possible to connect to the server at this time"

        case -1009:
            return "Server connection error"

        case -1011:
            return "Generic error"

        case -1012:
            return "It is not possible to connect to the server at this time"

        case -1013:
            return "User authentication required"

        case -1200:
            return "Connection SSL error, try again"

        case -1202:
            return "The certificate for this server is invalid"

        case 0:
            return ""

        case 101:
            return "The name contains at least one invalid character"

        case 200:
            return "Transfer stopped"

        case 207:
            return "WebDAV multistatus"

        case 304:
            return "Resource not modified"

        case 400:
            return "Bad request"

        case 401:
            return "Unauthorized"

        case 403:
            return "You don't have permission to complete the operation"

        case 404:
            return "The requested resource could not be found"

        case 405:
            return "The requested method is not supported"

        case 408:
            return "Request timeout"

        case 409:
            return "The request could not be completed due to a conflict with the current state of the resource"

        case 412:
            return "The server does not meet one of the preconditions of the request"

        case 413:
            return "The file is too large"

        case 417:
            return "Expectation failed"

        case 423:
            return "WebDAV Locked: Trying to access locked resource"

        case 429:
            return "Too many requests"

        case 500:
            return "Internal server error"

        case 502:
            return "Bad gateway"

        case 503:
            return "Server is currently in maintenance mode"

        case 504:
            return "Gateway timeout"

        case 507:
            return "Storage quota is reached"

        case NSURLErrorCannotDecodeContentData:
            return "Invalid data format"

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
            return "Generic error"
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
    ///   - errorDescription: The error description, mostly for logs.
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

        let message = NKError.firstNonEmpty(rootJson[.ocsDataMsg].string, rootJson[.ocsData].string, rootJson[.ocsMetaMsg].string)

        errorDescription = message ?? NKError.getErrorDescription(for: statuscode) ?? NKError.httpFallbackDescription(for: statuscode)

        self.responseData = responseData
        self.error = NSError(
            domain: NSCocoaErrorDomain,
            code: self.errorCode,
            userInfo: [NSLocalizedDescriptionKey: self.errorDescription]
        )
        self.kind = errorCode == 0 ? nil : Kind(code: statuscode)
        self.serverMessage = message
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
    ///   - request: The request, which tells some WebDAV statuses apart.
    ///   - responseData: Optional raw response data associated with the error.
    init(xmlData: Data, fallbackStatusCode: Int? = nil, request: URLRequest? = nil, responseData: Data? = nil) {
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
        self.kind = errorCode == 0 ? nil : Kind(davException: xml[.davException].text) ?? Kind(code: statuscode, request: request)
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
                    self.init(xmlData: errorData, fallbackStatusCode: errorCode, request: dataResponse?.request, responseData: responseData)
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
