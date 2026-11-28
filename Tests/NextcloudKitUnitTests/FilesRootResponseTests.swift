// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Claudio Cambra
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import NextcloudKit

struct FilesRootResponseTests {
    @Test(
        arguments: [("backend-user", "backend-user"), ("backend user", "backend%20user"), ("", "login%40example.invalid")],
        [("", ""), ("/nextcloud", "/nextcloud"), ("/nextcloud%20install/", "/nextcloud%20install")]
    )
    func identifiesFilesRoot(
        user: (id: String, hrefComponent: String),
        webroot: (baseURLPath: String, hrefPrefix: String)
    ) async throws {
        let common = NKCommon()
        let origin = "https://example.invalid"
        let session = NKSession(
            nkCommonInstance: common,
            urlBase: origin + webroot.baseURLPath,
            user: "login@example.invalid",
            userId: user.id,
            password: "",
            account: UUID().uuidString,
            userAgent: "NextcloudKitTests",
            groupIdentifier: "",
            httpMaximumConnectionsPerHost: 1,
            httpMaximumConnectionsPerHostInDownload: 1,
            httpMaximumConnectionsPerHostInUpload: 1
        )
        let rootHref = "\(webroot.hrefPrefix)/remote.php/dav/files/\(user.hrefComponent)/"
        let xml = """
        <d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
          <d:response>
            <d:href>\(rootHref)</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype><d:collection/></d:resourcetype>
                <oc:id>00000042instance</oc:id>
                <oc:fileid>42</oc:fileid>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>\(rootHref)\(user.hrefComponent)/</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype><d:collection/></d:resourcetype>
                <oc:id>00000043instance</oc:id>
                <oc:fileid>43</oc:fileid>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>\(webroot.hrefPrefix)/remote.php/dav%2Ffiles/\(user.hrefComponent)/</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype><d:collection/></d:resourcetype>
                <oc:id>00000044instance</oc:id>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        let files = await NKDataFileXML(nkCommonInstance: common).convertDataFile(
            xmlData: Data(xml.utf8),
            nkSession: session,
            rootFileName: common.rootFileName,
            showHiddenFiles: true,
            includeHiddenFiles: []
        )

        #expect(files.count == 3)
        let root = try #require(files.first { $0.ocId == "00000042instance" })
        let child = try #require(files.first { $0.ocId == "00000043instance" })
        let rootURL = try #require((origin + rootHref.dropLast()).removingPercentEncoding)
        let expectedUserID = try #require(user.hrefComponent.removingPercentEncoding)
        #expect(root.fileName == common.rootFileName)
        #expect(root.serverUrl == rootURL)
        #expect(root.directory)
        #expect(root.fileId == "42")
        #expect(child.fileName == expectedUserID)
        #expect(child.serverUrl == rootURL)
        #expect(child.directory)
        #expect(child.fileId == "43")
        let differentParent = try #require(files.first { $0.ocId == "00000044instance" })
        #expect(differentParent.fileName == expectedUserID)
    }
}
