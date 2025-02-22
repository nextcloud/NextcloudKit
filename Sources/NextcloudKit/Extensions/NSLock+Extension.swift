// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Claudio Cambra <claudio.cambra@nextcloud.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NSLock {
    @discardableResult
    func perform<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}
