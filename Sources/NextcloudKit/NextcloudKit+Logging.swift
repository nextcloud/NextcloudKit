// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

public extension NextcloudKit {
    /// Shared logger accessible via NextcloudKit.logger
    static var logger: NKLogFileManager {
        return NKLogFileManager.shared
    }

    /// Configure the shared logger from NextcloudKit
    static func configureLogger(printLog: Bool = true,
                                printColor: Bool = true,
                                logLevel: NKLogLevel = .normal,
                                retentionDays: Int = 30) {
        NKLogFileManager.configure(printLog: printLog,
                                   printColor: printColor,
                                   logLevel: logLevel,
                                   retentionDays: retentionDays)
    }
}
