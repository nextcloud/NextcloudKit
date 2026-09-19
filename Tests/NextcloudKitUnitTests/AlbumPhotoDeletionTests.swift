// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
import NextcloudKit

struct AlbumPhotoDeletionTests {
    @Test func emptyFileNameIsRejectedBeforeSessionLookup() async {
        // No session: invalid input must be rejected before URL or request creation.
        let result: Result<String, NKError> = await withCheckedContinuation { continuation in
            NextcloudKit.shared.deletePhotoFromAlbum(
                albumName: "Holiday",
                fileName: "",
                account: UUID().uuidString,
                taskHandler: { _ in Issue.record("Deletion must not create a network task") }
            ) { result in
                continuation.resume(returning: result)
            }
        }
        switch result {
        case .success:
            Issue.record("An empty file name must not succeed")
        case .failure(let error):
            #expect(error == .invalidData)
        }
    }

    @Test func asyncDeletionRejectsEmptyFileName() async {
        do {
            try await NextcloudKit.shared.deletePhotoFromAlbumAsync(
                albumName: "Holiday",
                fileName: "",
                account: UUID().uuidString,
                taskHandler: { _ in Issue.record("Deletion must not create a network task") }
            )
            Issue.record("An empty file name must throw")
        } catch let error as NKError {
            #expect(error == .invalidData)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
