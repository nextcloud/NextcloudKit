// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Errors specific to the parsing of Nextcloud login codes, as in QR codes or login callback URLs.
///
enum QRCodeError: Error, LocalizedError {
    case implausibleLength
    case invalidPrefix
    case missingHost
    case missingPassword
    case missingUser

    var errorDescription: String? {
        switch self {
        case .implausibleLength, .invalidPrefix:
            String(localized: "This is not a valid login code.", bundle: .module, comment: "Error message when a scanned QR code is not a Nextcloud login code.")
        case .missingHost:
            String(localized: "The login code is missing the server address.", bundle: .module, comment: "Error message when a login QR code has no server address.")
        case .missingPassword:
            String(localized: "The login code is missing the password.", bundle: .module, comment: "Error message when a login QR code has no password.")
        case .missingUser:
            String(localized: "The login code is missing the user name.", bundle: .module, comment: "Error message when a login QR code has no user name.")
        }
    }
}

///
/// Credentials parsed from a login code, tagged with which login variant they represent.
///
struct LoginCredentials {
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
protocol QRCodeParsing {}

extension QRCodeParsing {
    ///
    /// Parse a login QR code into ``LoginCredentials``, distinguishing direct logins
    /// (`<scheme>://login/…`) from onetime logins (`<scheme>://onetime-login/…`).
    ///
    func parseLogin(_ code: String, scheme: String = "nc") throws -> LoginCredentials {
        let onetimePrefix = "\(scheme)://onetime-login/"
        let loginPrefix = "\(scheme)://login/"

        let kind: LoginCredentials.Kind
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

        return LoginCredentials(kind: kind, user: user, password: password, host: host)
    }

    ///
    /// Parse the `<scheme>://login/…` URL a server or sign-up provider redirects to after a successful login.
    ///
    func parseLoginCallback(_ url: URL, scheme: String = "nc") throws -> LoginCredentials {
        let (user, password, host) = try decomposeLoginCode(url.absoluteString, prefix: "\(scheme)://login/", decodingValues: true)

        return LoginCredentials(kind: .login, user: user, password: password, host: host)
    }
}

///
/// Decompose a `<prefix>user:…&password:…&server:…` login code into its values, in any order.
///
/// - Parameters:
///     - decodingValues: Whether values are percent-decoded and `+` in the user name means a space, as in the URL the server redirects to after a login.
///
private func decomposeLoginCode(_ code: String, prefix loginCodePrefix: String, decodingValues: Bool = false) throws -> (user: String, password: String, host: URL) {
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

    let compositeKeyValuePairs = code.dropFirst(loginCodePrefix.count).components(separatedBy: "&")
    var decomposedKeyValuePairs = [String: String]()

    compositeKeyValuePairs.forEach { compositeKeyValuePair in
        let parts = compositeKeyValuePair.split(separator: ":", maxSplits: 1)

        guard parts.count == 2 else {
            return
        }

        let key = String(parts[0])
        var value = String(parts[1])

        if decodingValues {
            if key == "user" {
                value = value.replacingOccurrences(of: "+", with: " ")
            }

            value = value.removingPercentEncoding ?? value
        }

        decomposedKeyValuePairs[key] = value
    }

    guard let user = decomposedKeyValuePairs["user"] else {
        throw QRCodeError.missingUser
    }

    guard let password = decomposedKeyValuePairs["password"] else {
        throw QRCodeError.missingPassword
    }

    guard let hostString = decomposedKeyValuePairs["server"], let host = URL(string: hostString), host.host != nil else {
        throw QRCodeError.missingHost
    }

    return (user: user, password: password, host: host)
}
