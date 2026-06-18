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
/// Credentials parsed from a login QR code, tagged with which login variant they represent.
///
struct ParsedLoginCredentials {
    ///
    /// Whether the password is a ready-to-use app password (`login`) or a onetime token that
    /// still has to be exchanged for an app password (`onetimeLogin`).
    ///
    enum Kind {
        case login
        case onetimeLogin
    }

    let kind: Kind
    let user: String

    ///
    /// The app password for ``Kind/login`` or the onetime token for ``Kind/onetimeLogin``.
    ///
    let password: String
    let host: URL
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
        try decomposeLoginCode(code, prefix: "nc://login/")
    }

    ///
    /// Parse a login QR code into ``ParsedLoginCredentials``, distinguishing direct logins
    /// (`nc://login/…`) from onetime logins (`nc://onetime-login/…`).
    ///
    func parseLogin(_ code: String) throws -> ParsedLoginCredentials {
        let onetimePrefix = "nc://onetime-login/"
        let loginPrefix = "nc://login/"

        let kind: ParsedLoginCredentials.Kind
        let prefix: String

        if code.hasPrefix(onetimePrefix) {
            kind = .onetimeLogin
            prefix = onetimePrefix
        } else if code.hasPrefix(loginPrefix) {
            kind = .login
            prefix = loginPrefix
        } else {
            throw QRCodeError.invalidPrefix
        }

        let (user, password, host) = try decomposeLoginCode(code, prefix: prefix)
        return ParsedLoginCredentials(kind: kind, user: user, password: password, host: host)
    }
}

///
/// Decompose a `<prefix>user:…&password:…&server:…` login code into its values.
///
private func decomposeLoginCode(_ code: String, prefix loginCodePrefix: String) throws -> (user: String, password: String, host: URL) {
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
