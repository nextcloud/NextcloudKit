// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Compression

/// Defines the severity level of a log message.
/// Defines the level of log verbosity.
public enum NKLogLevel: Int, CaseIterable, Identifiable, Comparable {
    /// Logging is disabled.
    case off = 0

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
        case .off: return NSLocalizedString("_disabled_", comment: "")
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
    ///   - retentionDays: Number of days to keep compressed logs.

    public static func configure(printLog: Bool = true,
                                 printColor: Bool = true,
                                 minLevel: NKLogLevel = .normal,
                                 retentionDays: Int = 30) {
        shared.setConfiguration(printLog: printLog, printColor: printColor, minLevel: minLevel, retentionDays: retentionDays)
    }

    /// Returns the file URL of the currently active log file.
    public func currentLogFileURL() -> URL {
        return logDirectory.appendingPathComponent(logFileName)
    }

    // MARK: - Configuration

    private let logFileName = "log.txt"
    private let logDirectory: URL
    private var printLog: Bool
    private var printColor: Bool = true
    public var minLevel: NKLogLevel
    private var currentLogDate: String
    private var retentionDays: Int
    private let logQueue = DispatchQueue(label: "LogWriterQueue", attributes: .concurrent)
    private let fileManager = FileManager.default

    // MARK: - Initialization

    private init(printLog: Bool = true, minLevel: NKLogLevel = .normal, retentionDays: Int = 30) {
        self.printLog = printLog
        self.minLevel = minLevel
        self.retentionDays = retentionDays

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
    private func setConfiguration(printLog: Bool, printColor: Bool, minLevel: NKLogLevel, retentionDays: Int) {
        self.printLog = printLog
        self.printColor = printColor
        self.minLevel = minLevel
        self.retentionDays = retentionDays
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

    /// Writes a tagged log message with a specific log level.
    /// - Parameters:
    ///   - tag: A custom tag to classify the log message (e.g. "SYNC", "AUTH").
    ///   - message: The log message content.
    ///   - level: The minimum level required for this message to be written.
    public func writeLog(tag: String, message: String) {
        guard !tag.isEmpty else { return }

        writeLog("[\(tag.uppercased())] \(message)")
    }

    public func writeLog(_ message: String?) {
        guard minLevel != .off else { return }
        guard let message = message else { return }

        let fileTimestamp = Self.stableTimestampString()
        let consoleTimestamp = Self.localizedTimestampString()
        let fullMessage = "\(fileTimestamp) \(message)\n"

        if printLog {
            let consoleLine = printColor
                ? emojiColored("\(consoleTimestamp) \(message)")
                : "\(consoleTimestamp) \(message)"
            print(consoleLine)
        }

        logQueue.async(flags: .barrier) {
            self.checkForRotation()
            self.appendToLog(fullMessage)
        }
    }

    private func emojiColored(_ message: String) -> String {
        if message.contains("[ERROR]") {
            return "🔴 " + message
        } else if message.contains("[WARNING]") {
            return "🟡 " + message
        } else if message.contains("[INFO]") {
            return "🟢 " + message
        } else if message.contains("[DEBUG]") {
            return "⚪️ " + message
        } else {
            return "🔷 " + message
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
        let rotatedPath = logDirectory.appendingPathComponent("log-\(date)")
        let compressedPath = rotatedPath.appendingPathExtension("gz")

        do {
            if fileManager.fileExists(atPath: currentPath.path) {
                try fileManager.moveItem(at: currentPath, to: rotatedPath)
                try compressFile(at: rotatedPath, to: compressedPath)
                try fileManager.removeItem(at: rotatedPath)
            }

            try Data().write(to: currentPath)
            cleanupOldLogs()
        } catch {
            print("Log rotation failed: \(error)")
        }
    }

    private func cleanupOldLogs() {
        let calendar = Calendar.current
        let now = Date()

        guard let enumerator = try? fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return
        }

        for fileURL in enumerator {
            guard fileURL.pathExtension == "gz" else { continue }

            if let attrs = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = attrs.contentModificationDate,
               let expiryDate = calendar.date(byAdding: .day, value: -retentionDays, to: now),
               modDate < expiryDate {
                try? fileManager.removeItem(at: fileURL)
            }
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

    // MARK: - Compression

    private func compressFile(at inputURL: URL, to outputURL: URL) throws {
        let inputData = try Data(contentsOf: inputURL)
        var compressedBuffer = [UInt8](repeating: 0, count: inputData.count)

        let compressedSize = inputData.withUnsafeBytes { srcPtr in
            compression_encode_buffer(
                &compressedBuffer,
                compressedBuffer.count,
                srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                inputData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else {
            throw NSError(domain: "CompressionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Compression failed"])
        }

        let compressedData = Data(bytes: compressedBuffer, count: compressedSize)
        try compressedData.write(to: outputURL)
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
