// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Errors specific to the parsing of Nextcloud login QR codes.
///
enum QRCodeError: Error {
    case implausibleLength
    case invalidPrefix
    case missingHost
    case missingPassword
    case missingUser
}

///
/// Logic for parsing the atomic data values from a composite string as provided through a QR code for logging in.
///
protocol QRCodeParsing {
    ///
    /// Extract individual bits from a composite string as in an QR code for logging in.
    ///
    /// - Parameters:
    ///     - code: The raw string which is attained from a scanned QR code.
    ///
    /// - Returns: A tuple consisting of the user name, app password and server address in this exact order.
    ///
    func parse(_ code: String) throws -> (user: String, password: String, host: URL)
}

extension QRCodeParsing {
    func parse(_ code: String) throws -> (user: String, password: String, host: URL) {
        let loginCodePrefix = "nc://login/"

        guard code.count > loginCodePrefix.count else {
            throw QRCodeError.implausibleLength
        }

        guard code.hasPrefix(loginCodePrefix) else {
            throw QRCodeError.invalidPrefix
        }

        guard code.contains("user:") else {
            throw QRCodeError.missingUser
        }

        guard code.contains("password:") else {
            throw QRCodeError.missingPassword
        }

        guard code.contains("server:") else {
            throw QRCodeError.missingHost
        }

        guard let prefixRange = code.range(of: loginCodePrefix) else {
            throw QRCodeError.invalidPrefix
        }

        let compositeKeyValuePairs = code[prefixRange.upperBound...].components(separatedBy: "&")
        var decomposedKeyValuePairs = [String: String]()

        compositeKeyValuePairs.forEach { compositeKeyValuePair in
            let parts = compositeKeyValuePair.split(separator: ":", maxSplits: 1)

            guard parts.count == 2 else {
                return
            }

            decomposedKeyValuePairs[String(parts[0])] = String(parts[1])
        }

        guard let user = decomposedKeyValuePairs["user"] else {
            throw QRCodeError.missingUser
        }

        guard let password = decomposedKeyValuePairs["password"] else {
            throw QRCodeError.missingPassword
        }

        guard let hostString = decomposedKeyValuePairs["server"], let host = URL(string: hostString) else {
            throw QRCodeError.missingHost
        }

        return (user: user, password: password, host: host)
    }
}
