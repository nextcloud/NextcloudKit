// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import NextcloudKit

struct AlbumResponseTests {
    @Test(arguments: [
        "/nextcloud/remote.php/dav/photos/alice/albums/",
        "/nextcloud/remote.php/dav/photos/alice/albums",
        "https://example.com/nextcloud/remote.php/dav/photos/alice/albums/"
    ])
    func excludesCollectionButKeepsAnAlbumNamedAlbums(collectionHref: String) throws {
        let collectionURL = try #require(URL(string: "https://example.com/nextcloud/remote.php/dav/photos/alice/albums/"))
        let albumHref = "/nextcloud/remote.php/dav/photos/alice/albums/albums/"
        let xml = """
        <d:multistatus xmlns:d="DAV:" xmlns:nc="http://nextcloud.org/ns">
          <d:response>
            <d:href>\(collectionHref)</d:href>
            <d:propstat><d:prop><nc:nbItems>1</nc:nbItems></d:prop>
              <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
          </d:response>
          <d:response>
            <d:href>\(albumHref)</d:href>
            <d:propstat><d:prop><nc:nbItems>2</nc:nbItems></d:prop>
              <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
          </d:response>
        </d:multistatus>
        """
        let albums = NextcloudKit.shared.parseAlbumsXML(account: "alice", data: Data(xml.utf8), collectionURL: collectionURL)
        #expect(albums.map(\.href) == [albumHref])
        #expect(albums.first?.name == "albums")
    }

    @Test(arguments: [
        "/nextcloud/remote.php/dav/files/alice/photo.jpg",
        "remote.php/dav/files/alice/photo.jpg",
        "https://example.com/nextcloud/remote.php/dav/files/alice/photo.jpg"
    ])
    func resolvesSourcePathsWithoutDuplicatingInstallation(sourcePath: String) {
        for base in ["https://example.com/nextcloud", "https://example.com/nextcloud/"] {
            let url = NextcloudKit.shared.albumPhotoSourceURL(sourcePath: sourcePath, serverUrl: base)
            #expect(url?.absoluteString == "https://example.com/nextcloud/remote.php/dav/files/alice/photo.jpg")
        }
    }

    @Test func preservesSpecialCharactersInRawSourceNames() {
        let url = NextcloudKit.shared.albumPhotoSourceURL(
            sourcePath: "/nextcloud/remote.php/dav/files/alice/holiday #100%.jpg",
            serverUrl: "https://example.com/nextcloud")
        #expect(url?.absoluteString == "https://example.com/nextcloud/remote.php/dav/files/alice/holiday%20%23100%25.jpg")
    }
}
