// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import NextcloudKit

struct FileResponseTests {
    @Test
    func parsesStandardFileResponse() async throws {
        let files = await parse("""
        <d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
          <d:response>
            <d:href>/remote.php/dav/files/user/document.txt</d:href>
            <d:propstat>
              <d:prop>
                <oc:id>00000042instance</oc:id>
                <oc:fileid>42</oc:fileid>
                <d:getetag>"current-etag"</d:getetag>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
            <d:propstat>
              <d:prop><oc:favorite/></d:prop>
              <d:status>HTTP/1.1 404 Not Found</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """)

        #expect(files.count == 1)
        let file = try #require(files.first)
        #expect(file.fileName == "document.txt")
        #expect(file.ocId == "00000042instance")
        #expect(file.fileId == "42")
        #expect(file.etag == "current-etag")
    }

    @Test
    func readsPropertiesFromAllSuccessfulGroups() async throws {
        let files = await parse("""
        <d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
          <d:response>
            <d:href>/remote.php/dav/files/user/document.txt</d:href>
            <d:propstat>
              <d:prop><d:getetag/></d:prop>
              <d:status>HTTP/1.1 404 Not Found</d:status>
            </d:propstat>
            <d:propstat>
              <d:prop><d:getetag>"current-etag"</d:getetag></d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
            <d:propstat>
              <d:prop><oc:id>00000042instance</oc:id></d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """)

        let file = try #require(files.first)
        #expect(file.ocId == "00000042instance")
        #expect(file.etag == "current-etag")
    }

    @Test
    func resolvesAlternateDefaultAndLocallyRedeclaredNamespaces() async throws {
        let files = await parse("""
        <dav:multistatus xmlns:dav="DAV:" xmlns:oc="urn:unrelated" xmlns:nc="http://nextcloud.org/ns">
          <response xmlns="DAV:">
            <href>/remote.php/dav/files/user/folder/</href>
            <propstat>
              <prop>
                <oc:id xmlns:oc="http://owncloud.org/ns">00000042instance</oc:id>
                <file:fileid xmlns:file="http://owncloud.org/ns">42</file:fileid>
                <resourcetype><collection/></resourcetype>
                <nc:metadata-photos-exif xmlns:exif="urn:exif">
                  <exif:Date>2026:11:16</exif:Date>
                </nc:metadata-photos-exif>
              </prop>
              <status>HTTP/1.1 200 OK</status>
            </propstat>
          </response>
        </dav:multistatus>
        """)

        let file = try #require(files.first)
        #expect(file.fileName == "folder")
        #expect(file.directory)
        #expect(file.ocId == "00000042instance")
        #expect(file.fileId == "42")
        #expect(file.exifPhotos == [["exif:Date": "2026:11:16"]])
    }

    @Test(arguments: ["", "<oc:id/>", "<unrelated:id>wrong-id</unrelated:id>"])
    func preservesMissingIDWithoutSubstitutingTheNumericFileID(_ property: String) async throws {
        let files = await parse("""
        <d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:unrelated="urn:unrelated">
          <d:response>
            <d:href>/remote.php/dav/files/user/document.txt</d:href>
            <d:propstat>
              <d:prop>
                \(property)
                <oc:fileid>42</oc:fileid>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
            <d:propstat>
              <d:prop><oc:id>unavailable-id</oc:id></d:prop>
              <d:status>HTTP/1.1 404 Not Found</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """)

        let file = try #require(files.first)
        #expect(file.ocId.isEmpty)
        #expect(file.fileId == "42")
    }

    @Test
    func rejectsIDFromAnUnrelatedNamespaceBoundToTheExpectedPrefix() async throws {
        let files = await parse("""
        <d:multistatus xmlns:d="DAV:" xmlns:oc="urn:unrelated">
          <d:response>
            <d:href>/remote.php/dav/files/user/document.txt</d:href>
            <d:propstat>
              <d:prop><oc:id>wrong-id</oc:id></d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """)

        let file = try #require(files.first)
        #expect(file.ocId.isEmpty)
    }

    private func parse(_ xml: String) async -> [NKFile] {
        let common = NKCommon()
        let session = NKSession(
            nkCommonInstance: common,
            urlBase: "https://example.invalid",
            user: "user",
            userId: "user",
            password: "",
            account: UUID().uuidString,
            userAgent: "NextcloudKitTests",
            groupIdentifier: "",
            httpMaximumConnectionsPerHost: 1,
            httpMaximumConnectionsPerHostInDownload: 1,
            httpMaximumConnectionsPerHostInUpload: 1
        )
        return await NKDataFileXML(nkCommonInstance: common).convertDataFile(
            xmlData: Data(xml.utf8),
            nkSession: session,
            rootFileName: common.rootFileName,
            showHiddenFiles: true,
            includeHiddenFiles: []
        )
    }
}
