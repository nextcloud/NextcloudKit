// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// Public logging helpers for apps using the NextcloudKit library.
// These functions internally use `NKLogFileManager.shared`.

@inlinable
public func nkLog(debug message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(debug: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(info message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(info: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(warning message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(warning: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(error message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(error: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(success message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(success: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(network message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(network: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(start message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(start: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(stop message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(stop: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(end message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(end: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

@inlinable
public func nkLog(cancel message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(cancel: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}

/// Logs a custom tagged message.
/// - Parameters:
///   - tag: A custom uppercase tag, e.g. \"PUSH\", \"SYNC\", \"AUTH\".
///   - emoji: the type tag .info, .debug, .warning, .error, .success ..
///   - message: The message to log.
///   - minimumLogLevel: set the minimun level for write the message
///   - consoleOnly: if true write the messa only in console
@inlinable
public func nkLog(tag: String, emoji: NKLogTagEmoji  = .debug, message: String, minimumLogLevel: NKLogLevel = .compact, consoleOnly: Bool = false) {
    NKLogFileManager.shared.writeLog(tag: tag, emoji: emoji, message: message, minimumLogLevel: minimumLogLevel, consoleOnly: consoleOnly)
}
