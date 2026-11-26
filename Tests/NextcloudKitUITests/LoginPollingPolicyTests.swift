// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
@testable import NextcloudKitUI
import Testing

///
/// Tests for ``LoginPollingPolicy``.
///
struct LoginPollingPolicyTests {
    @Test(arguments: [
        NSURLErrorNotConnectedToInternet,
        NSURLErrorTimedOut,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorCancelled,
        502,
        503,
        429
    ]) func transientErrors(_ errorCode: Int) async throws {
        #expect(LoginPollingPolicy.isTransient(NKError(errorCode: errorCode)))
    }

    @Test(arguments: [400, 401, 403, 500, NSURLErrorServerCertificateUntrusted, NSURLErrorBadServerResponse]) func terminalErrors(_ errorCode: Int) async throws {
        #expect(LoginPollingPolicy.isTransient(NKError(errorCode: errorCode)) == false)
    }
}
