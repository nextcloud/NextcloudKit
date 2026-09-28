// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public extension NextcloudKit {
    /// Shared logger accessible via NextcloudKit.logger
    static var logger: NKLogFileManager {
        return NKLogFileManager.shared
    }

    /// Configures the shared logger and optionally stores logs in a custom directory.
    static func configureLogger(logLevel: NKLogLevel = .normal, logDirectory: URL? = nil) {
        NKLogFileManager.configure(logLevel: logLevel, logDirectory: logDirectory)
    }

    /// Configure the shared logger blacklist from NextcloudKit
    static func configureLoggerBlacklist(blacklist: [String]) {
        NKLogFileManager.setBlacklist(blacklist: blacklist)
    }

    /// Configure the shared logger whitelist from NextcloudKit
    static func configureLoggerWhitelist(whitelist: [String]) {
        NKLogFileManager.setCandidate(whitelist: whitelist)
    }

    /// Waits until all pending log file writes have completed.
    static func flushLogger() {
        NKLogFileManager.flush()
    }
}
