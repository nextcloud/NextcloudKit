// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Foundation

public extension NKError {
    /// What went wrong, independent of how the server or the system worded it.
    ///
    /// Choose the message shown to people from this, and keep ``NKError/errorDescription`` for logs.
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
    /// Classifies an ``NKError/errorCode``: a URL loading error, an HTTP status or an OCS status code.
    ///
    /// Returns `nil` for `0`, which means success. The request method tells some WebDAV statuses apart.
    init?(code: Int, method: String? = nil) {
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
            self.init(httpStatusCode: code, method: method)
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
    init(urlErrorCode code: Int) {
        switch code {
        case NSURLErrorCancelled:
            self = .cancelled

        case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff, NSURLErrorCallIsActive:
            self = .offline

        case NSURLErrorTimedOut:
            self = .timeout

        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed:
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

    init(httpStatusCode: Int, method: String? = nil) {
        let method = method?.uppercased()

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

        case 412 where method == "COPY" || method == "MOVE":
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
