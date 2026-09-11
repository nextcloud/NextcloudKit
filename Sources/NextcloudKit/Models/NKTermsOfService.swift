// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKTermsOfService: NSObject {
    /// Source-compat alias for callers that still reference `NKTermsOfService.Meta`.
    public typealias Meta = NKOCSMeta

    public var meta: NKOCSMeta?
    public var data: OCSData?

    public override init() {
        super.init()
    }

    public func loadFromJSON(_ jsonData: Data) -> Bool {
        do {
            let decoded = try JSONDecoder().decode(NKOCSWrapper<OCSData>.self, from: jsonData)
            self.meta = decoded.ocs.meta
            self.data = decoded.ocs.data
            return true
        } catch {
            debugPrint("[DEBUG] decode error:", error)
            return false
        }
    }

    public func getTerms() -> [Term]? {
        return data?.terms
    }

    public func getLanguages() -> [String: String]? {
        return data?.languages
    }

    public func hasUserSigned() -> Bool {
        return data?.hasSigned ?? false
    }

    public func getMeta() -> NKOCSMeta? {
        return meta
    }

    public class OCSData: Codable {
        public let terms: [Term]
        public let languages: [String: String]
        public let hasSigned: Bool
    }

    public class Term: Codable {
        public let id: Int
        public let countryCode: String
        public let languageCode: String
        public let body: String
        public let renderedBody: String
    }
}
