// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Turn user input of a server address into a sanitized URL.
///
/// - Returns: If `input` is a valid URL, then the sanitized `URL` and otherwise `nil`.
///
protocol URLSanitizing {
    func sanitize(_ input: String) -> URL?
}

extension URLSanitizing {
    func sanitize(_ input: String) -> URL? {
        guard input.isEmpty == false else {
            return nil
        }

        guard var components = URLComponents(string: input) else {
            return nil
        }

        // Ensure HTTP(S) is used.
        if let givenScheme = components.scheme {
            if ["http", "https"].contains(givenScheme) == false {
                return nil
            }
        } else {
            components.scheme = "https"
        }

        if components.path.isEmpty {
            components.path = "/"
        } else {
            // Drop last path component, if it is a PHP script.
            let pathComponents = components.path.split(separator: "/")

            if let lastPathComponent = pathComponents.last, lastPathComponent == "index.php" {
                components.path = pathComponents.dropLast().joined(separator: "/")
            }

            // Add trailing slash, if missing.
            if components.path.hasSuffix("/") == false {
                components.path = "\(components.path)/"
            }
        }

        guard let url = components.url else {
            return nil
        }

        return url
    }
}
