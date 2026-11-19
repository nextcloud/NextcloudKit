// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Turn user input of a server address into a sanitized URL.
///
protocol URLSanitizing {}

extension URLSanitizing {
    ///
    /// - Parameters:
    ///     - input: The server address as typed, with or without scheme, port, path or a trailing `index.php`.
    ///     - upgradingInsecureHTTP: Whether an explicit `http` scheme is replaced with `https`.
    ///
    /// - Returns: If `input` is a valid HTTP(S) address, then the sanitized `URL` ending in `/` and otherwise `nil`.
    ///
    func sanitize(_ input: String, upgradingInsecureHTTP: Bool = false) -> URL? {
        var address = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard address.isEmpty == false else {
            return nil
        }

        // Without a scheme, URLComponents reads "host" as a path and "host:8080" as a scheme.
        if address.hasPrefix("//") {
            address = "https:\(address)"
        } else if address.contains("://") == false {
            address = "https://\(address)"
        }

        guard var components = URLComponents(string: address),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              host.isEmpty == false else {
            return nil
        }

        components.scheme = upgradingInsecureHTTP ? "https" : scheme
        components.query = nil
        components.fragment = nil

        var pathComponents = components.path.split(separator: "/").map(String.init)

        if pathComponents.last == "index.php" {
            pathComponents.removeLast()
        }

        components.path = "/" + pathComponents.joined(separator: "/")

        if components.path.hasSuffix("/") == false {
            components.path += "/"
        }

        return components.url
    }
}
