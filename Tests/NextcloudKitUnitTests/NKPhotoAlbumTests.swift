// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
import NextcloudKit

struct NKPhotoAlbumTests {
    @Test func identityIsScopedToAccountAndStableAcrossMetadataChanges() {
        let album = NKPhotoAlbum(account: "a", href: "/albums/one/")
        let updated = NKPhotoAlbum(account: "a", href: album.href, itemCount: 3)
        let otherAccount = NKPhotoAlbum(account: "b", href: album.href)
        #expect(album.id == updated.id)
        #expect(album.id != otherAccount.id)
        #expect(Set([album, album]).count == 1)
    }

    @Test func nameDecodesOnlyTheLastPathComponent() {
        let album = NKPhotoAlbum(account: "a", href: "/albums/Caff%C3%A8%20%23%20100%25%2Festate/")
        #expect(album.name == "Caffè # 100%/estate")
        #expect(NKPhotoAlbum(account: "a", href: "/albums/100%/").name == "100%")
        #expect(NKPhotoAlbum(account: "a", href: "").name.isEmpty)
    }

    @Test func dateRangeUsesUnixSecondsAndPreservesRawValue() {
        let raw = #"{"start":1700000000,"end":1700003600}"#
        let album = NKPhotoAlbum(account: "a", href: "/albums/one/", dateRange: raw)
        #expect(album.startDate == Date(timeIntervalSince1970: 1700000000))
        #expect(album.endDate == Date(timeIntervalSince1970: 1700003600))
        #expect(album.dateRange == raw)
    }

    @Test(arguments: [nil, "", "invalid", "{}", #"{"start":1}"#, #"{"start":2,"end":1}"#, #"{"start":"1","end":2}"#] as [String?])
    func invalidDateRangesHaveNoDates(raw: String?) {
        let album = NKPhotoAlbum(account: "a", href: "/albums/one/", dateRange: raw)
        #expect(album.startDate == nil)
        #expect(album.endDate == nil)
    }
}
