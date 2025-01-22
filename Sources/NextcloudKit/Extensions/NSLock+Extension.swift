//
//  NSLock+Extension.swift
//  NextcloudKit
//
//  Created by Claudio Cambra on 2025-01-22.
//

import Foundation

extension NSLock {
    @discardableResult
    func perform<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}
