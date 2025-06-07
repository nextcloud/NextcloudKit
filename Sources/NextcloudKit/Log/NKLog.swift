// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Public logging helpers for apps using the NextcloudKit library.
/// These functions internally use `NKLogFileManager.shared`.

@inlinable
public func log(debug message: String) {
    NKLogFileManager.shared.writeLog(debug: message)
}

@inlinable
public func log(info message: String) {
    NKLogFileManager.shared.writeLog(info: message)
}

@inlinable
public func log(warning message: String) {
    NKLogFileManager.shared.writeLog(warning: message)
}

@inlinable
public func log(error message: String) {
    NKLogFileManager.shared.writeLog(error: message)
}

/// Logs a custom tagged message at the specified level.
/// - Parameters:
///   - tag: A custom uppercase tag, e.g. \"UPLOAD\", \"SYNC\", \"AUTH\".
///   - message: The message to log.
///   - level: The minimum level required for the message to be recorded.
@inlinable
public func log(tag: String, message: String, level: LogLevel = .normal) {
    NKLogFileManager.shared.writeLog(tag: tag, message: message, level: level)
}
