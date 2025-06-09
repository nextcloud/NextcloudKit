// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Defines the severity level of a log message.
/// Defines the level of log verbosity.
public enum NKLogLevel: Int, CaseIterable, Identifiable, Comparable {
    /// Logging is disabled.
    case disabled = 0

    /// Logs basic request lifecycle for developers (request started, response result).
    case trace = 1

    /// Logs important info such as result content, errors.
    case normal = 2

    /// Logs detailed debug info like headers and bodies.
    case verbose = 3

    // Needed for Picker
    public var id: Int { rawValue }

    // For Picker display
    public var displayText: String {
        switch self {
        case .disabled: return NSLocalizedString("_disabled_", comment: "")
        case .trace: return NSLocalizedString("_trace_", comment: "")
        case .normal: return NSLocalizedString("_normal_", comment: "")
        case .verbose: return NSLocalizedString("_verbose_", comment: "")
        }
    }

    // For Comparable
    public static func < (lhs: NKLogLevel, rhs: NKLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Type for writes a tagged log message
public enum NKLogTypeTag: String {
    case debug = "[DEBUG]"
    case info = "[INFO]"
    case warning = "[WARNING]"
    case error = "[ERROR]"
    case success = "[SUCCESS]"
}

/// A logger that writes log messages to a file in a subdirectory of the user's Documents folder,
/// rotates the log daily, and compresses old logs with GZip.
/// Compatible with iOS 13.0+ and Swift 6.
public final class NKLogFileManager {

    // MARK: - Singleton

    /// Shared singleton instance of the log manager.
    public static let shared = NKLogFileManager()

    /// Configures the shared logger instance.
    /// - Parameters:
    ///   - printLog: Whether to print logs to the console.
    ///   - printColor: Whether to print logs to the console with the emojiColored
    ///   - minLevel: The minimum log level to be recorded.

    public static func configure(printLog: Bool = true,
                                 printColor: Bool = true,
                                 logLevel: NKLogLevel = .normal) {
        shared.setConfiguration(printLog: printLog, printColor: printColor, logLevel: logLevel)
    }

    /// Returns the file URL of the currently active log file.
    public func currentLogFileURL() -> URL {
        return logDirectory.appendingPathComponent(logFileName)
    }

    // MARK: - Configuration

    private let logFileName = "log.md"
    private let logDirectory: URL
    private var printLog: Bool
    public var printColor: Bool = true
    public var logLevel: NKLogLevel
    private var currentLogDate: String
    private let logQueue = DispatchQueue(label: "LogWriterQueue", attributes: .concurrent)
    private let fileManager = FileManager.default

    // MARK: - Initialization

    private init(printLog: Bool = true, logLevel: NKLogLevel = .normal) {
        self.printLog = printLog
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
    ///   - printLog: Whether to print logs to the console.
    ///   - printColor: Whether to print logs to the console with the emojiColored
    ///   - minLevel: The minimum log level.
    ///   - retentionDays: Number of days to retain compressed logs.
    ///
    private func setConfiguration(printLog: Bool, printColor: Bool, logLevel: NKLogLevel) {
        self.printLog = printLog
        self.printColor = printColor
        self.logLevel = logLevel
    }

    // MARK: - Public API

    public func compressedLogs() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension == "gz" }
    }

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

    public func writeLog(network message: String) {
        writeLog("[NETWORK] \(message)")
    }

    /// Writes a tagged log message with a specific log level.
    /// - Parameters:
    ///   - tag: A custom tag to classify the log message (e.g. "SYNC", "AUTH").
    ///   - message: The log message content.
    ///   - level: The minimum level required for this message to be written.
    public func writeLog(tag: String, typeTag: NKLogTypeTag, message: String) {
        guard !tag.isEmpty else { return }
        let emojiColored = printColor ? emojiColored(typeTag.rawValue) : ""

        writeLog("\(emojiColored)[\(tag.uppercased())] \(message)")
    }

    public func writeLog(_ message: String?) {
        guard logLevel != .disabled else { return }
        guard let message = message else { return }

        let fileTimestamp = Self.stableTimestampString()
        let consoleTimestamp = Self.localizedTimestampString()
        let emoji = printColor ? emojiColored(message) : ""
        let fullMessage = "\(fileTimestamp) \(emoji)\(message)\n"

        if printLog {
            let consoleLine = "\(consoleTimestamp) \(emoji)\(message)"
            print(consoleLine)
        }

        logQueue.async(flags: .barrier) {
            self.checkForRotation()
            self.appendToLog(fullMessage)
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
        let rotatedPath = logDirectory.appendingPathComponent("log-\(date).md")

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

    // MARK: - Date Helpers

    private static func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func stableTimestampString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    private static func localizedTimestampString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
}
