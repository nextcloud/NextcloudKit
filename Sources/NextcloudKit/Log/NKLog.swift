// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// Public logging helpers for apps using the NextcloudKit library.
// These functions internally use `NKLogFileManager.shared`.

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
public func nkLog(success message: String) {
    NKLogFileManager.shared.writeLog(success: message)
}

@inlinable
public func nkLog(network message: String) {
    NKLogFileManager.shared.writeLog(network: message)
}

@inlinable
public func nkLog(start message: String) {
    NKLogFileManager.shared.writeLog(start: message)
}

@inlinable
public func nkLog(stop message: String) {
    NKLogFileManager.shared.writeLog(stop: message)
}

/// Logs a custom tagged message.
/// - Parameters:
///   - tag: A custom uppercase tag, e.g. \"PUSH\", \"SYNC\", \"AUTH\".
///   - emoji: the type tag .info, .debug, .warning, .error, .success ..
///   - message: The message to log.
@inlinable
public func nkLog(tag: String, emoji: NKLogTagEmoji  = .debug, message: String) {
    NKLogFileManager.shared.writeLog(tag: tag, emoji: emoji, message: message)
}
