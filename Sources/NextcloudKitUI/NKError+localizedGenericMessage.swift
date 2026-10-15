// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

public extension NKError {
    ///
    /// User friendly messages for generic errors. Each one fits a `kind`.
    ///
    var localizedGenericMessage: String {
        if let userFacingServerMessage {
            return userFacingServerMessage
        }

        switch kind ?? .unknown {
        case .offline:
            return String(localized: "You're offline. Please check your internet connection.", bundle: .module, comment: "Error message when the device has no internet connection.")

        case .timeout:
            return String(localized: "The server took too long to respond. Try again later.", bundle: .module, comment: "Error message when a request to the server timed out.")

        case .serverUnreachable:
            return String(localized: "Can't reach the server. Check the address or try again later.", bundle: .module, comment: "Error message when the server cannot be reached.")

        case .secureConnection:
            return String(localized: "A secure connection to the server couldn't be established.", bundle: .module, comment: "Error message for TLS and certificate failures.")

        case .unauthorized:
            return String(localized: "Your login is no longer valid. Please log in again.", bundle: .module, comment: "Error message when the server rejects the account's credentials.")

        case .forbidden:
            return String(localized: "You don't have permission to do this.", bundle: .module, comment: "Error message when the server forbids the action.")

        case .notFound:
            return String(localized: "The item could not be found on the server.", bundle: .module, comment: "Error message when the requested file, folder or share does not exist on the server.")

        case .alreadyExists:
            return String(localized: "An item with this name already exists.", bundle: .module, comment: "Error message when a file or folder with the same name already exists.")

        case .conflict:
            return String(localized: "The item was changed on the server. Please refresh and try again.", bundle: .module, comment: "Error message when the request conflicts with the current state on the server.")

        case .locked:
            return String(localized: "The file is locked. Try again later.", bundle: .module, comment: "Error message when the file is locked on the server.")

        case .quotaExceeded:
            return String(localized: "There is not enough storage space left on the server.", bundle: .module, comment: "Error message when the account's storage quota is used up.")

        case .tooLarge:
            return String(localized: "The file is too large for the server.", bundle: .module, comment: "Error message when the server rejects a file because of its size.")

        case .rateLimited:
            return String(localized: "Too many requests. Please wait a moment and try again.", bundle: .module, comment: "Error message when the server rate-limits the requests.")

        case .unavailable:
            return String(localized: "The server is temporarily unavailable. Try again later.", bundle: .module, comment: "Error message when the server is unavailable, e.g. in maintenance mode.")

        case .serverError:
            return String(localized: "The server ran into a problem. Try again later.", bundle: .module, comment: "Error message for internal server errors.")

        case .invalidResponse:
            return String(localized: "The server sent an unexpected response. Try again later.", bundle: .module, comment: "Error message when the server's response cannot be read.")

        case .localStorageFull:
            return String(localized: "There is not enough storage space left on this device.", bundle: .module, comment: "Error message when the device runs out of storage space.")

        case .cancelled:
            return String(localized: "The request was cancelled.", bundle: .module, comment: "Error message when a request was cancelled.")

        case .unknown:
            return String(localized: "Something went wrong. Please try again.", bundle: .module, comment: "Error message when the cause of the error is unknown.")
        }
    }
}
