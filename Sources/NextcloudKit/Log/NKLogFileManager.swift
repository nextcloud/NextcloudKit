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
public enum LogLevel: Int, Comparable {
    /// Logging is disabled.
    case off = 0

    /// Logs essential events such as requests and errors.
    case normal = 1

    /// Logs detailed debug information including headers and bodies.
    case verbose = 2

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
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
    ///   - minLevel: The minimum log level to be recorded.
    ///   - retentionDays: Number of days to keep compressed logs.
    public static func configure(printLog: Bool = true,
                                 minLevel: LogLevel = .normal,
                                 retentionDays: Int = 30) {
        shared.setConfiguration(printLog: printLog, minLevel: minLevel, retentionDays: retentionDays)
    }

    // MARK: - Configuration

    private let logFileName = "log.txt"
    private let logDirectory: URL
    private var printLog: Bool
    internal var minLevel: LogLevel
    private var currentLogDate: String
    private var retentionDays: Int
    private let logQueue = DispatchQueue(label: "LogWriterQueue", attributes: .concurrent)
    private let fileManager = FileManager.default

    // MARK: - Initialization

    private init(printLog: Bool = true, minLevel: LogLevel = .normal, retentionDays: Int = 30) {
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
    ///   - minLevel: The minimum log level.
    ///   - retentionDays: Number of days to retain compressed logs.
    private func setConfiguration(printLog: Bool, minLevel: LogLevel, retentionDays: Int) {
        self.printLog = printLog
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
        guard minLevel == .verbose else { return }
        writeLog("[DEBUG] \(message)")
    }

    public func writeLog(info message: String) {
        guard minLevel >= .normal else { return }
        writeLog("[INFO] \(message)")
    }

    public func writeLog(warning message: String) {
        guard minLevel >= .normal else { return }
        writeLog("[WARNING] \(message)")
    }

    public func writeLog(error message: String) {
        guard minLevel >= .normal else { return }
        writeLog("[ERROR] \(message)")
    }

    public func writeLog(tag: String, message: String) {
        guard !tag.isEmpty else { return }
        guard minLevel >= .normal else { return }
        writeLog("[\(tag.uppercased())] \(message)")
    }

    public func writeLog(_ message: String?) {
        guard minLevel != .off else { return }
        guard let message = message else { return }

        let fileTimestamp = Self.stableTimestampString()
        let consoleTimestamp = Self.localizedTimestampString()
        let fullMessage = "\(fileTimestamp) \(message)\n"

        if printLog {
            print(colored("\(consoleTimestamp) \(message)"))
        }

        logQueue.async(flags: .barrier) {
            self.checkForRotation()
            self.appendToLog(fullMessage)
        }
    }

    private func colored(_ message: String) -> String {
        let reset = "\u{001B}[0m"
        if message.contains("[ERROR]") {
            return "\u{001B}[0;31m" + message + reset
        } else if message.contains("[WARNING]") {
            return "\u{001B}[0;33m" + message + reset
        } else if message.contains("[INFO]") {
            return "\u{001B}[0;32m" + message + reset
        } else if message.contains("[DEBUG]") {
            return "\u{001B}[0;37m" + message + reset
        } else {
            return "\u{001B}[0;36m" + message + reset
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
