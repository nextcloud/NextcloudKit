// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import NextcloudKit

/// Records the transfer results NextcloudKit reports to its delegate.
final class RecordingNextcloudKitDelegate: NextcloudKitDelegate {
    let uploadErrors: AsyncStream<NKError>
    private let uploadErrorsContinuation: AsyncStream<NKError>.Continuation

    init() {
        let (uploadErrors, uploadErrorsContinuation) = AsyncStream<NKError>.makeStream()

        self.uploadErrors = uploadErrors
        self.uploadErrorsContinuation = uploadErrorsContinuation
    }

    func uploadComplete(fileName: String, serverUrl: String, allHeaderFields: [AnyHashable: Any]?, task: URLSessionTask, error: NKError) {
        uploadErrorsContinuation.yield(error)
    }
}
