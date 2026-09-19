// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct NKPhotoAlbum: Identifiable, Hashable, Sendable {
    public let account: String
    public let href: String
    public let lastPhotoId: String?
    public let itemCount: Int?
    public let location: String?
    public let dateRange: String?
    public let collaborators: String?

    /// Stable identity scoped to the account, independent of album metadata.
    public var id: String { "\(account.utf8.count):\(account)\(href)" }

    /// The album name decoded from the last component of its DAV path.
    public var name: String {
        guard let component = href.split(separator: "/").last else { return href }
        return String(component).removingPercentEncoding ?? String(component)
    }

    /// Dates supplied by the server, or nil when the date range is missing or invalid.
    public let startDate: Date?
    public let endDate: Date?

    public init(account: String,
                href: String,
                lastPhotoId: String? = nil,
                itemCount: Int? = nil,
                location: String? = nil,
                dateRange: String? = nil,
                collaborators: String? = nil) {
        self.account = account
        self.href = href
        self.lastPhotoId = lastPhotoId
        self.itemCount = itemCount
        self.location = location
        self.dateRange = dateRange
        self.collaborators = collaborators

        if let data = dateRange?.data(using: .utf8),
           let range = try? JSONDecoder().decode([String: TimeInterval].self, from: data),
           let start = range["start"], let end = range["end"],
           start.isFinite, end.isFinite, start <= end {
            self.startDate = Date(timeIntervalSince1970: start)
            self.endDate = Date(timeIntervalSince1970: end)
        } else {
            self.startDate = nil
            self.endDate = nil
        }
    }
}
