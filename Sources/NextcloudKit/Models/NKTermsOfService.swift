// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public class NKTermsOfService: NSObject {
    public var meta: Meta?
    public var data: OCSData?

    public override init() {
        super.init()
    }

    public func loadFromJSON(_ jsonData: Data) -> Bool {
        do {
            let decodedResponse = try JSONDecoder().decode(OCSResponse.self, from: jsonData)
            self.meta = decodedResponse.ocs.meta
            self.data = decodedResponse.ocs.data
            return true
        } catch {
            debugPrint("decode error:", error)
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

    public func getMeta() -> Meta? {
        return meta
    }

    // MARK: - Codable
    private class OCSResponse: Codable {
        let ocs: OCS
    }

    private class OCS: Codable {
        let meta: Meta
        let data: OCSData
    }

    public class Meta: Codable {
        public let status: String
        public let statuscode: Int
        public let message: String
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
