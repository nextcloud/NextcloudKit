// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Public logging helpers for apps using the NextcloudKit library.
/// These functions internally use `NKLogFileManager.shared`.

@inlinable
public func nkLog(debug message: String) {
    NKLogFileManager.shared.writeLog(debug: message)
}

@inlinable
public func nkLog(info message: String) {
    NKLogFileManager.shared.writeLog(info: message)
}

@inlinable
public func nkLog(warning message: String) {
    NKLogFileManager.shared.writeLog(warning: message)
}

@inlinable
public func nkLog(error message: String) {
    NKLogFileManager.shared.writeLog(error: message)
}

@inlinable
public func nkLog(network message: String) {
    NKLogFileManager.shared.writeLog(network: message)
}

/// Logs a custom tagged message at the specified level.
/// - Parameters:
///   - tag: A custom uppercase tag, e.g. \"UPLOAD\", \"SYNC\", \"AUTH\".
///   - message: The message to log.
///   - level: The minimum level required for the message to be recorded.
@inlinable
public func nkLog(tag: String, typeTag: NKLogTypeTag = .debug, message: String) {
    NKLogFileManager.shared.writeLog(tag: tag, typeTag: typeTag, message: message)
}
