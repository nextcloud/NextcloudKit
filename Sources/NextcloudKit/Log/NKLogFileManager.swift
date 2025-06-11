// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// Defines the severity level of a log message.
// Defines the level of log verbosity.
public enum NKLogLevel: Int, CaseIterable, Identifiable, Comparable {
    // Logging is disabled.
    case disabled = 0

    // Logs basic request lifecycle for developers (request started, response result).
    case compact = 1

    // Logs important info such as result content, errors.
    case normal = 2

    // Logs detailed debug info like headers and bodies.
    case verbose = 3

    // Needed for Picker
    public var id: Int { rawValue }

    // For Picker display
    public var displayText: String {
        switch self {
        case .disabled: return NSLocalizedString("_disabled_", comment: "")
        case .compact: return NSLocalizedString("_compact_", comment: "")
        case .normal: return NSLocalizedString("_normal_", comment: "")
        case .verbose: return NSLocalizedString("_verbose_", comment: "")
        }
    }

    // For Comparable
    public static func < (lhs: NKLogLevel, rhs: NKLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Type for writes a emoji in writeLog(tag: ...)
public enum NKLogTagEmoji: String {
    case error = "[ERROR]"
    case success = "[SUCCESS]"
    case warning = "[WARNING]"
    case info = "[INFO]"
    case debug = "[DEBUG]"
    case network = "[NETWORK]"
    case start = "[START]"
    case stop = "[STOP]"
}

/// A logger that writes log messages to a file in a subdirectory of the user's Documents folder,
/// rotates the log daily
/// Compatible with iOS 13.0+ and Swift 6.
public final class NKLogFileManager {

    // MARK: - Singleton

    /// Shared singleton instance of the log manager.
    public static let shared = NKLogFileManager()

    /// Configures the shared logger instance.
    /// - Parameters:
    ///   - minLevel: The minimum log level to be recorded.

    public static func configure(logLevel: NKLogLevel = .normal) {
        shared.setConfiguration(logLevel: logLevel)
    }

    /// Returns the file URL of the currently active log file.
    public func currentLogFileURL() -> URL {
        return logDirectory.appendingPathComponent(logFileName)
    }

    // MARK: - Configuration

    private let logFileName = "log.txt"
    private let logDirectory: URL
    public var logLevel: NKLogLevel
    private var currentLogDate: String
    private let logQueue = DispatchQueue(label: "LogWriterQueue", attributes: .concurrent)
    private let rotationQueue = DispatchQueue(label: "LogRotationQueue")
    private let fileManager = FileManager.default

    /// Cache for dynamic format strings, populated at runtime. Thread-safe via serial queue.
    private static var cachedDynamicFormatters: [String: DateFormatter] = [:]
    private static let formatterAccessQueue = DispatchQueue(label: "com.yourapp.dateformatter.cache")

    // MARK: - Initialization

    private init(logLevel: NKLogLevel = .normal) {
        self.logLevel = logLevel

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsFolder = documents.appendingPathComponent("Logs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: logsFolder.path) {
            try? FileManager.default.createDirectory(at: logsFolder, withIntermediateDirectories: true)
        }
        self.logDirectory = logsFolder
        self.currentLogDate = Self.currentDateString()
    }

    /// Sets configuration parameters for the logger.
    /// - Parameters:
    ///   - logLevel: The NKLogLevel { disabled .. verbose }
    private func setConfiguration(logLevel: NKLogLevel) {
        self.logLevel = logLevel
    }

    // MARK: - Public API

    public func writeLog(debug message: String) {
        writeLog("[DEBUG] \(message)")
    }

    public func writeLog(info message: String) {
        writeLog("[INFO] \(message)")
    }

    public func writeLog(warning message: String) {
        writeLog("[WARNING] \(message)")
    }

    public func writeLog(error message: String) {
        writeLog("[ERROR] \(message)")
    }

    public func writeLog(success message: String) {
        writeLog("[SUCCESS] \(message)")
    }

    public func writeLog(network message: String) {
        writeLog("[NETWORK] \(message)")
    }

    public func writeLog(start message: String) {
        writeLog("[START] \(message)")
    }

    public func writeLog(stop message: String) {
        writeLog("[STOP] \(message)")
    }

    /// Writes a tagged log message with a specific log level.
    /// - Parameters:
    ///   - tag: A custom tag to classify the log message (e.g. "SYNC", "AUTH").
    ///   - emoji: .info, .debug, .warning, .error, .success ..
    ///   - message: The log message content.
    public func writeLog(tag: String, emoji: NKLogTagEmoji, message: String) {
        guard !tag.isEmpty else { return }

        let taggedMessage = "[\(tag.uppercased())] \(message)"
        writeLog(taggedMessage, emoji: emoji)
    }

    /// Writes a log message with an optional typeTag to determine console emoji.
    /// Emojis and keyword replacements (e.g. [SUCCESS] -> 🟢) are only applied to the console output.
    /// The file output remains clean (no emoji or substitutions).
    ///
    /// - Parameters:
    ///   - message: The log message to record.
    ///   - emoji: Optional type to determine console emoji (e.g. [INFO], [ERROR]).
    public func writeLog(_ message: String?, emoji: NKLogTagEmoji? = nil) {
        guard logLevel != .disabled, let message = message else { return }

        let fileTimestamp = Self.stableTimestampString()
        let consoleTimestamp = Self.localizedTimestampString()
        let fileLine = "\(fileTimestamp) \(message)\n"

        // Determine which emoji to display in console
        let emoji = emoji.map { emojiColored($0.rawValue) } ?? emojiColored(message)

        // Visual message with inline replacements
        let visualMessage = message
            .replacingOccurrences(of: "RESPONSE: SUCCESS", with: "🟢")
            .replacingOccurrences(of: "RESPONSE: ERROR", with: "🔴")

        // Build the console line with emoji
        let consoleLine = "[NKLOG] [\(consoleTimestamp)] \(emoji)\(visualMessage)"
        print(consoleLine)

        rotationQueue.sync {
            self.checkForRotation()
        }

        logQueue.async {
            self.appendToLog(fileLine)
        }
    }

    private func emojiColored(_ message: String) -> String {
        if message.contains("[ERROR]") {
            return "🔴 "
        } else if message.contains("[SUCCESS]") {
            return "🟢 "
        } else if message.contains("[WARNING]") {
            return "🟡 "
        } else if message.contains("[INFO]") {
            return "🔵 "
        } else if message.contains("[DEBUG]") {
            return "⚪️ "
        } else if message.contains("[NETWORK]") {
            return "🌐 "
        } else if message.contains("[START]") {
            return "🚀 "
        } else if message.contains("[STOP]") {
            return "⏹️ "
        } else {
            return ""
        }
    }

    // MARK: - Log Rotation

    private func checkForRotation() {
        let today = Self.currentDateString()
        guard today != currentLogDate else { return }

        rotateLog(for: currentLogDate)
        currentLogDate = today
    }

    private func rotateLog(for date: String) {
        let currentPath = logDirectory.appendingPathComponent(logFileName)
        let rotatedPath = logDirectory.appendingPathComponent("log-\(date).txt")

        do {
            if fileManager.fileExists(atPath: currentPath.path) {
                try fileManager.moveItem(at: currentPath, to: rotatedPath)
            }

            // Create a new empty log file for today
            try Data().write(to: currentPath)

        } catch {
            print("Log rotation failed: \(error)")
        }
    }

    // MARK: - Log Writing

    private func appendToLog(_ message: String) {
        let logPath = logDirectory.appendingPathComponent(logFileName)

        guard let data = message.data(using: .utf8) else { return }

        if fileManager.fileExists(atPath: logPath.path) {
            if let handle = FileHandle(forWritingAtPath: logPath.path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logPath)
        }
    }

    // MARK: - Cached DateFormatters

    /// Cached formatter for "yyyy-MM-dd". Uses current calendar, locale, and time zone.
    private static let cachedCurrentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Cached formatter for "yyyy-MM-dd HH:mm:ss". Uses en_US_POSIX locale and Gregorian calendar for stable output.
    private static let cachedStableTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    /// Cached formatter using `.short` dateStyle and `.medium` timeStyle with current calendar and locale.
    private static let cachedLocalizedTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    /// Returns a cached `DateFormatter` instance for the given format string.
    /// Formatters are created on-demand and reused to improve performance.
    private static func cachedFormatter(for format: String) -> DateFormatter {
        return formatterAccessQueue.sync {
            if let formatter = cachedDynamicFormatters[format] {
                return formatter
            }

            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            cachedDynamicFormatters[format] = formatter
            return formatter
        }
    }

    /// Converts a `String` into a `Date` using a cached formatter for the specified format.
    /// - Parameters:
    ///   - string: The date string to convert.
    ///   - format: The format pattern (e.g., "EEE, dd MMM y HH:mm:ss zzz").
    /// - Returns: A `Date` object if parsing succeeds; otherwise `nil`.
    public func convertDate(_ string: String, format: String) -> Date? {
        let formatter = Self.cachedFormatter(for: format)
        return formatter.date(from: string)
    }

    /// Converts a `Date` to a `String` using a cached formatter for the specified format.
    /// - Parameters:
    ///   - date: The `Date` to format.
    ///   - format: The format string (e.g., "yyyy-MM-dd HH:mm:ss").
    /// - Returns: The formatted date string.
    public func convertDate(_ date: Date, format: String) -> String {
        let formatter = Self.cachedFormatter(for: format)
        return formatter.string(from: date)
    }

    /// Returns today's date string in "yyyy-MM-dd" format using a cached formatter.
    private static func currentDateString() -> String {
        return cachedCurrentDateFormatter.string(from: Date())
    }

    /// Returns a stable timestamp string in "yyyy-MM-dd HH:mm:ss" format using a cached formatter.
    private static func stableTimestampString() -> String {
        return cachedStableTimestampFormatter.string(from: Date())
    }

    /// Returns a localized timestamp string using short date and medium time styles.
    private static func localizedTimestampString() -> String {
        return cachedLocalizedTimestampFormatter.string(from: Date())
    }
 }
