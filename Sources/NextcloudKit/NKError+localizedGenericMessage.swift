// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public extension NKError {
    /// The message to show users: the share API's own message when there is one, otherwise a translated message for ``kind``.
    var localizedGenericMessage: String {
        if let userFriendlyServerMessage {
            return userFriendlyServerMessage
        }

        switch kind ?? .unknown {
        case .offline:
            return NSLocalizedString("You're offline. Please check your internet connection.", bundle: .module, comment: "Error message when the device has no internet connection.")

        case .timeout:
            return NSLocalizedString("The server took too long to respond. Try again later.", bundle: .module, comment: "Error message when a request to the server timed out.")

        case .serverUnreachable:
            return NSLocalizedString("Can't reach the server. Check the address or try again later.", bundle: .module, comment: "Error message when the server cannot be reached.")

        case .secureConnection:
            return NSLocalizedString("A secure connection to the server couldn't be established.", bundle: .module, comment: "Error message for TLS and certificate failures.")

        case .unauthorized:
            return NSLocalizedString("Your login is no longer valid. Please log in again.", bundle: .module, comment: "Error message when the server rejects the account's credentials.")

        case .forbidden:
            return NSLocalizedString("You don't have permission to do this.", bundle: .module, comment: "Error message when the server forbids the action.")

        case .notFound:
            return NSLocalizedString("The item could not be found on the server.", bundle: .module, comment: "Error message when the requested file, folder or share does not exist on the server.")

        case .alreadyExists:
            return NSLocalizedString("An item with this name already exists.", bundle: .module, comment: "Error message when a file or folder with the same name already exists.")

        case .invalidName:
            return NSLocalizedString("This name isn't allowed.", bundle: .module, comment: "Error message when the server rejects a file or folder name.")

        case .conflict:
            return NSLocalizedString("The item was changed on the server. Please refresh and try again.", bundle: .module, comment: "Error message when the request conflicts with the current state on the server.")

        case .locked:
            return NSLocalizedString("The file is locked. Try again later.", bundle: .module, comment: "Error message when the file is locked on the server.")

        case .quotaExceeded:
            return NSLocalizedString("There is not enough storage space left on the server.", bundle: .module, comment: "Error message when the account's storage quota is used up.")

        case .tooLarge:
            return NSLocalizedString("The file is too large for the server.", bundle: .module, comment: "Error message when the server rejects a file because of its size.")

        case .rateLimited:
            return NSLocalizedString("Too many requests. Please wait a moment and try again.", bundle: .module, comment: "Error message when the server rate-limits the requests.")

        case .unavailable:
            return NSLocalizedString("The server is temporarily unavailable. Try again later.", bundle: .module, comment: "Error message when the server is unavailable, e.g. in maintenance mode.")

        case .serverError:
            return NSLocalizedString("The server ran into a problem. Try again later.", bundle: .module, comment: "Error message for internal server errors.")

        case .invalidResponse:
            return NSLocalizedString("The server sent an unexpected response. Try again later.", bundle: .module, comment: "Error message when the server's response cannot be read.")

        case .localStorageFull:
            return NSLocalizedString("There is not enough storage space left on this device.", bundle: .module, comment: "Error message when the device runs out of storage space.")

        case .cancelled:
            return NSLocalizedString("The request was cancelled.", bundle: .module, comment: "Error message when a request was cancelled.")

        case .unknown:
            return NSLocalizedString("Something went wrong. Please try again.", bundle: .module, comment: "Error message when the cause of the error is unknown.")
        }
    }
}
