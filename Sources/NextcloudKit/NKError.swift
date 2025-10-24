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
}

public struct NKError: Error, Equatable, Sendable {
    static let internalError = -9999
    public let errorCode: Int
    public let errorDescription: String
    public let error: Error
    public let responseData: Data?

    public static let urlError = NKError(errorCode: NSURLErrorBadURL, errorDescription: NSLocalizedString("_invalid_url_", value: "Invalid server url", comment: ""))
    public static let invalidResponseError = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: NSLocalizedString("_error_response_", value: "Invalid response", comment: ""))
    public static let xmlError = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: NSLocalizedString("_error_decode_xml_", value: "Invalid response, error decoding XML", comment: ""))
    public static let invalidDate = NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: NSLocalizedString("_invalid_date_format_", value: "Invalid date format", comment: ""))
    public static let invalidData = NKError(errorCode: NSURLErrorCannotDecodeContentData, errorDescription: NSLocalizedString("_invalid_data_format_", value: "Invalid data format", comment: ""))
    public static let unauthorizedError = NKError(errorCode: 401, errorDescription: NSLocalizedString("_unauthorized_", value: "Unauthorized", comment: ""))
    public static let unavailableError = NKError(errorCode: 503, errorDescription: NSLocalizedString("_Unavailable_", value: "Unavailable", comment: ""))
    public static let forbiddenError = NKError(errorCode: 403, errorDescription: NSLocalizedString("_forbidden_", value: "Forbidden", comment: ""))
    public static let cancelled = NKError(errorCode: -999, errorDescription: NSLocalizedString("_cancelled_", value: "Cancelled", comment: ""))

    public static let errorChunkFileNull = NKError(errorCode: -9994, errorDescription: NSLocalizedString("_error_file_null_", value: "File not found", comment: ""))
    public static let errorChunkFilesEmpty = NKError(errorCode: -9995, errorDescription: NSLocalizedString("_chunk_files_empty_", value: "Files not found", comment: ""))
    public static let errorChunkCreateFolder = NKError(errorCode: -9996, errorDescription: NSLocalizedString("_error_create_folder_", value: "Create folder error", comment: ""))
    public static let errorChunkMoveFile = NKError(errorCode: -9997, errorDescription: NSLocalizedString("_error_move_folder_", value: "Move file error", comment: ""))
    public static let errorChunkNoEnoughMemory = NKError(errorCode: -9998, errorDescription: NSLocalizedString("_no_enough_memory_", value: "No enough memory", comment: ""))

    public static let success = NKError(errorCode: 0, errorDescription: "")

    public static func getErrorDescription(for code: Int) -> String? {
        switch code {
        case -9999:
            return NSLocalizedString("_internal_server_", value: "Internal error", comment: "")
        case -1001:
            return NSLocalizedString("_time_out_", value: "Time out", comment: "")
        case -1004:
            return NSLocalizedString("_server_down_", value: "The server appears to be down", comment: "")
        case -1005:
            return NSLocalizedString("_not_possible_connect_to_server_", value: "It is not possible to connect to the server at this time", comment: "")
        case -1009:
            return NSLocalizedString("_not_connected_internet_", value: "Server connection error", comment: "")
        case -1011:
            return NSLocalizedString("_error_", value: "Generic error", comment: "")
        case -1012:
            return NSLocalizedString("_not_possible_connect_to_server_", value: "It is not possible to connect to the server at this time", comment: "")
        case -1013:
            return NSLocalizedString("_user_authentication_required_", value: "User authentication required", comment: "")
        case -1200:
            return NSLocalizedString("_ssl_connection_error_", value: "Connection SSL error, try again", comment: "")
        case -1202:
            return NSLocalizedString("_ssl_certificate_untrusted_", value: "The certificate for this server is invalid", comment: "")
        case 0: return ""
        case 101:
            return NSLocalizedString("_forbidden_characters_from_server_", value: "The name contains at least one invalid character", comment: "")
        case 304:
            return NSLocalizedString("_error_not_modified_", value: "Resource not modified", comment: "")
        case 400:
            return NSLocalizedString("_bad_request_", value: "Bad request", comment: "")
        case 401:
            return NSLocalizedString("_unauthorized_", value: "Unauthorized", comment: "")
        case 403:
            return NSLocalizedString("_error_not_permission_", value: "You don't have permission to complete the operation", comment: "")
        case 404:
            return NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: "")
        case 405:
            return NSLocalizedString("_method_not_allowed_", value: "The requested method is not supported", comment: "")
        case 409:
            return NSLocalizedString("_error_conflict_", value: "The request could not be completed due to a conflict with the current state of the resource", comment: "")
        case 412:
            return NSLocalizedString("_error_precondition_", value: "The server does not meet one of the preconditions that the requester", comment: "")
        case 413:
            return NSLocalizedString("_request_entity_too_large_", value: "The file is too large", comment: "")
        case 423:
            return NSLocalizedString("_webdav_locked_", value: "WebDAV Locked: Trying to access locked resource", comment: "")
        case 500:
            return NSLocalizedString("_internal_server_", value: "Internal server error", comment: "")
        case 503:
            return NSLocalizedString("_server_maintenance_mode_", value: "Server is currently in maintenance mode", comment: "")
        case 507:
            return NSLocalizedString("_user_over_quota_", value: "Storage quota is reached", comment: "")
        case 200:
            return NSLocalizedString("_transfer_stopped_", value: "Transfer stopped", comment: "")
        case 207:
            return NSLocalizedString("_error_multi_status_", value: "WebDAV multistatus", comment: "")
        case NSURLErrorCannotDecodeContentData:
            return NSLocalizedString("_invalid_data_format_", value: "Invalid data format", comment: "")
        default:
            return nil
        }
    }

    public init(errorCode: Int = 0, errorDescription: String = "", responseData: Data? = nil) {
        self.errorCode = errorCode
        self.errorDescription = errorDescription
        self.error = NSError(domain: NSCocoaErrorDomain, code: self.errorCode, userInfo: [NSLocalizedDescriptionKey: self.errorDescription])
        self.responseData = responseData
    }

    public init(error: Error, responseData: Data? = nil) {
        self.errorCode = error._code
        self.errorDescription = error.localizedDescription
        self.error = error
        self.responseData = responseData
    }

    public init(nsError: NSError, responseData: Data? = nil) {
        self.errorCode = nsError.code
        self.errorDescription = nsError.localizedDescription
        self.error = nsError
        self.responseData = responseData
    }

    public init(rootJson: JSON, fallbackStatusCode: Int?, responseData: Data? = nil) {
        let statuscode = rootJson[.ocsMetaCode].int ?? fallbackStatusCode ?? NSURLErrorCannotDecodeContentData
        errorCode = 200..<300 ~= statuscode ? 0 : statuscode

        if let dataMsg = rootJson[.ocsDataMsg].string {
            errorDescription = dataMsg
        } else if let metaMsg = rootJson[.ocsMetaMsg].string {
            errorDescription = metaMsg
        } else {
            errorDescription = NKError.getErrorDescription(for: statuscode) ?? ""
        }
        self.responseData = responseData
        self.error = NSError(domain: NSCocoaErrorDomain, code: self.errorCode, userInfo: [NSLocalizedDescriptionKey: self.errorDescription])
    }

    public init(statusCode: Int, fallbackDescription: String, responseData: Data? = nil) {
        self.errorCode = statusCode
        self.errorDescription = "\(statusCode): " + (NKError.getErrorDescription(for: statusCode) ?? fallbackDescription)
        self.error = NSError(domain: NSCocoaErrorDomain, code: self.errorCode, userInfo: [NSLocalizedDescriptionKey: self.errorDescription])
        self.responseData = responseData
    }

    init(httpResponse: HTTPURLResponse) {
        self.init(statusCode: httpResponse.statusCode, fallbackDescription: httpResponse.description)
    }

    init(xmlData: Data, fallbackStatusCode: Int? = nil, responseData: Data? = nil) {
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
            errorDescription = NKError.getErrorDescription(for: statuscode) ?? ""
        }
        self.responseData = responseData
        self.error = NSError(domain: NSCocoaErrorDomain, code: self.errorCode, userInfo: [NSLocalizedDescriptionKey: self.errorDescription])
    }

    public init<T: AFResponse>(error: AFError?, afResponse: T, responseData: Data? = nil) {
        if let errorCode = afResponse.response?.statusCode {
            guard let dataResponse = afResponse as? Alamofire.DataResponse<T.Success, T.Failure>,
                  let errorData = dataResponse.data
            else {
                self.init(statusCode: errorCode, fallbackDescription: afResponse.response?.description ?? "", responseData: responseData)
                return
            }

            if let errorJson = try? JSON(data: errorData) {
                self.init(rootJson: errorJson, fallbackStatusCode: errorCode, responseData: responseData)
            } else {
                self.init(xmlData: errorData, fallbackStatusCode: errorCode, responseData: responseData)
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
    }

    public static func == (lhs: NKError, rhs: NKError) -> Bool {
        return lhs.errorCode == rhs.errorCode && lhs.errorDescription == rhs.errorDescription
    }

    public static func == (lhs: NKError, rhs: NKError?) -> Bool {
        if let rhs {
            return lhs == rhs;
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
