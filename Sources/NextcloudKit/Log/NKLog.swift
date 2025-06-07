//
//  NKLog.swift
//  NextcloudKit
//
//  Created by Marino Faggiana on 07/06/25.
//

import Foundation

/// Internal log helpers for use inside the NextcloudKit module.
internal func log(debug message: String) {
    NKLogFileManager.shared.writeLog(debug: message)
}

internal func log(info message: String) {
    NKLogFileManager.shared.writeLog(info: message)
}

internal func log(warning message: String) {
    NKLogFileManager.shared.writeLog(warning: message)
}

internal func log(error message: String) {
    NKLogFileManager.shared.writeLog(error: message)
}

internal func log(tag: String, message: String) {
    NKLogFileManager.shared.writeLog(tag: tag, message: message)
}
