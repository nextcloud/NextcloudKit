// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Parses the `<scheme>://login/server:…&user:…&password:…` URL a server or sign-up provider redirects to after a successful login.
///
public enum LoginCallbackParser {
    public static func parse(_ url: URL, scheme: String = "nc") throws -> LoginCredentials {
        try parse(url.absoluteString, scheme: scheme)
    }

    public static func parse(_ string: String, scheme: String = "nc") throws -> LoginCredentials {
        let (user, password, host) = try decomposeLoginCode(string, prefix: "\(scheme)://login/", decodingValues: true)

        return LoginCredentials(kind: .login, user: user, password: password, host: host)
    }
}
