// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftyXMLParser

///
/// Result of a file lock or unlock operation.
///
public struct NKLockOperationResult: Sendable {
    ///
    /// Normalized resource ETag returned by the operation.
    ///
    public let etag: String?

    ///
    /// The created lock, or `nil` when the resource was unlocked.
    ///
    public let lock: NKLock?

    ///
    /// Creates a lock operation result.
    ///
    public init(etag: String? = nil, lock: NKLock? = nil) {
        self.etag = etag
        self.lock = lock
    }

    init(data: Data) {
        self.init(xml: XML.parse(data)["d:prop"])
    }

    init(xml properties: XML.Accessor) {
        self.etag = Self.normalizedETag(properties["d:getetag"].text)
        self.lock = NKLock(xml: properties)
    }

    static func normalizedETag(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return normalized.isEmpty ? nil : normalized
    }
}
