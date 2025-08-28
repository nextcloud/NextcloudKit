// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

public extension NextcloudKit {
    /// Shared logger accessible via NextcloudKit.logger
    static var logger: NKLogFileManager {
        return NKLogFileManager.shared
    }

    /// Configure the shared logger from NextcloudKit
    static func configureLogger(logLevel: NKLogLevel = .normal) {
        NKLogFileManager.configure(logLevel: logLevel)
    }

    /// Configure the shared logger blacklist from NextcloudKit
    static func configureLoggerBlacklist(blacklist: [String]) {
        NKLogFileManager.setBlacklist(blacklist: blacklist)
    }

    /// Configure the shared logger whitelist from NextcloudKit
    static func configureLoggerWhitelist(whitelist: [String]) {
        NKLogFileManager.setCandidate(whitelist: whitelist)
    }
}
