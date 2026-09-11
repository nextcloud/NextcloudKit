// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Generic `Decodable` envelope for OCS v2 responses.
/// Server replies follow `{ "ocs": { "meta": ..., "data": ... } }`.
public struct NKOCSWrapper<T: Decodable>: Decodable {
    public let ocs: Inner

    public struct Inner: Decodable {
        public let meta: NKOCSMeta
        public let data: T
    }
}

/// OCS response metadata. `message` is optional per the OCS contract.
public struct NKOCSMeta: Decodable, Sendable {
    public let status: String
    public let statuscode: Int
    public let message: String?
}
