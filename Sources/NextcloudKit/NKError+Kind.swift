// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Foundation

public extension NKError {
    /// What went wrong, independent of how the server or the system worded it.
    ///
    /// Choose the message shown to users from this, and keep ``NKError/errorDescription`` for logs.
    enum Kind: Sendable, CaseIterable {
        case offline
        case timeout
        case serverUnreachable
        case secureConnection
        case unauthorized
        case forbidden
        case notFound
        /// `MKCOL` on an existing folder, or `COPY`/`MOVE` onto an existing item without overwriting it.
        case alreadyExists
        /// The server doesn't accept the file or folder name.
        case invalidName
        case conflict
        case locked
        case quotaExceeded
        case tooLarge
        case rateLimited
        /// HTTP 503, which includes maintenance mode.
        case unavailable
        case serverError
        case invalidResponse
        case localStorageFull
        case cancelled
        case unknown
    }
}

extension NKError.Kind {
    /// Classifies the WebDAV exceptions that the HTTP status alone doesn't tell apart.
    init?(davException: String?) {
        guard davException == "OCA\\DAV\\Connector\\Sabre\\Exception\\InvalidPath" else { return nil }

        self = .invalidName
    }

    /// Classifies an ``NKError/errorCode``: a URL loading error, an HTTP status or an OCS status code.
    ///
    /// Returns `nil` for `0`, which means success. The request tells some WebDAV statuses apart.
    init?(code: Int, request: URLRequest? = nil) {
        switch code {
        case 0:
            return nil

        case ..<0:
            self.init(urlErrorCode: code)

        case 996:
            self = .serverError

        case 997:
            self = .unauthorized

        case 998:
            self = .notFound

        default:
            self.init(httpStatusCode: code, request: request)
        }
    }

    /// Classifies any error, using its domain to tell codes apart.
    init(error: Error) {
        if let error = error as? NKError {
            self = error.kind ?? .unknown
        } else if error is CancellationError {
            self = .cancelled
        } else if error is DecodingError {
            self = .invalidResponse
        } else if let error = error as? AFError {
            self.init(afError: error)
        } else {
            self.init(nsError: error as NSError)
        }
    }
}

extension NKError.Kind {
    private init(urlErrorCode code: Int) {
        switch code {
        case NSURLErrorCancelled:
            self = .cancelled

        case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff, NSURLErrorCallIsActive:
            self = .offline

        case NSURLErrorTimedOut:
            self = .timeout

        case NSURLErrorBadURL, NSURLErrorUnsupportedURL, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed:
            self = .serverUnreachable

        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorServerCertificateNotYetValid, NSURLErrorClientCertificateRejected, NSURLErrorClientCertificateRequired, NSURLErrorAppTransportSecurityRequiresSecureConnection:
            self = .secureConnection

        case NSURLErrorUserCancelledAuthentication, NSURLErrorUserAuthenticationRequired:
            self = .unauthorized

        case NSURLErrorBadServerResponse, NSURLErrorZeroByteResource, NSURLErrorCannotDecodeRawData, NSURLErrorCannotDecodeContentData,
             NSURLErrorCannotParseResponse, NSURLErrorHTTPTooManyRedirects, NSURLErrorRedirectToNonExistentLocation:
            self = .invalidResponse

        case NSURLErrorResourceUnavailable:
            self = .unavailable

        case NSURLErrorDataLengthExceedsMaximum:
            self = .tooLarge

        default:
            self = .unknown
        }
    }

    private init(httpStatusCode: Int, request: URLRequest? = nil) {
        let method = request?.httpMethod?.uppercased()

        switch httpStatusCode {
        case 401:
            self = .unauthorized

        case 403:
            self = .forbidden

        case 404, 410:
            self = .notFound

        case 405 where method == "MKCOL":
            self = .alreadyExists

        case 408, 504:
            self = .timeout

        case 409:
            self = .conflict

        case 412 where NKError.Kind.refusesOverwrite(request):
            self = .alreadyExists

        case 412:
            self = .conflict

        case 413:
            self = .tooLarge

        case 423:
            self = .locked

        case 429:
            self = .rateLimited

        case 502:
            self = .serverUnreachable

        case 503:
            self = .unavailable

        case 507:
            self = .quotaExceeded

        case 500...511:
            self = .serverError

        default:
            self = .unknown
        }
    }

    /// A `COPY` or `MOVE` that may not replace an existing item. Other 412s are failed state preconditions such as `If-Match`.
    private static func refusesOverwrite(_ request: URLRequest?) -> Bool {
        let method = request?.httpMethod?.uppercased()

        guard let request, method == "COPY" || method == "MOVE" else { return false }

        let hasStatePrecondition = request.value(forHTTPHeaderField: "If-Match") != nil || request.value(forHTTPHeaderField: "If") != nil

        return request.value(forHTTPHeaderField: "Overwrite")?.uppercased() == "F" && !hasStatePrecondition
    }

    private init(afError: AFError) {
        if afError.isExplicitlyCancelledError {
            self = .cancelled
        } else if afError.isServerTrustEvaluationError {
            self = .secureConnection
        } else if let code = afError.responseCode {
            self.init(httpStatusCode: code)
        } else if afError.isResponseSerializationError {
            self = .invalidResponse
        } else if let underlyingError = afError.underlyingError {
            self.init(error: underlyingError)
        } else {
            self = .unknown
        }
    }

    private init(nsError: NSError) {
        switch (nsError.domain, nsError.code) {
        case (NSURLErrorDomain, _):
            self.init(urlErrorCode: nsError.code)

        case (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError), (NSPOSIXErrorDomain, Int(ENOSPC)):
            self = .localStorageFull

        case (NSCocoaErrorDomain, NSUserCancelledError):
            self = .cancelled

        case (NSCocoaErrorDomain, NSPropertyListReadCorruptError):
            self = .invalidResponse

        default:
            self = .unknown
        }
    }
}
