// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A thread-safe container for managing an array of `NKSession` instances.
///
/// Every access takes a lock and completes on the calling thread, so no access waits for another thread to be started.
/// Waiting for one can deadlock: while every Swift concurrency thread is blocked, the system may not start a worker thread for a concurrent dispatch queue.
/// Conforms to `@unchecked Sendable` for Swift 6 compatibility.
public final class SynchronizedNKSessionArray: @unchecked Sendable {

    // MARK: - Internal Storage

    /// Internal storage for the session array.
    private var array: [NKSession]

    /// Lock guarding every access to `array`.
    private let lock = NSLock()

    // MARK: - Initialization

    /// Initializes a new synchronized array with optional initial content.
    /// - Parameter initial: An initial array of `NKSession` to populate the container with.
    public init(_ initial: [NKSession] = []) {
        self.array = initial
    }

    // MARK: - Read Operations

    /// Returns the number of sessions currently stored.
    public var count: Int {
        lock.perform { array.count }
    }

    /// Returns a Boolean value indicating whether the array is empty.
    public var isEmpty: Bool {
        lock.perform { array.isEmpty }
    }

    /// Returns a snapshot of all stored sessions.
    public var all: [NKSession] {
        lock.perform { array }
    }

    /// Calls the given closure on each session in the array, in order.
    ///
    /// The closure runs on a snapshot taken under the lock, so it may access this array itself.
    /// - Parameter body: A closure that takes a `NKSession` as a parameter.
    public func forEach(_ body: (NKSession) -> Void) {
        all.forEach(body)
    }

    /// Returns the first session matching a given account string.
    /// - Parameter account: The account identifier string to match.
    /// - Returns: A `NKSession` instance if found, otherwise `nil`.
    public func session(forAccount account: String) -> NKSession? {
        lock.perform {
            for session in array {
                if session.account == account {
                    return session
                }
            }
            return nil
        }
    }

    /// Checks whether a session for a given account exists.
    /// - Parameter account: The account identifier string to check.
    /// - Returns: `true` if a matching session exists, `false` otherwise.
    public func contains(account: String) -> Bool {
        lock.perform {
            array.contains(where: { $0.account == account })
        }
    }

    /// Replaces the first stored session that matches the given account identifier with a new session.
    ///
    /// The replacement is done under the lock and has completed when this method returns.
    /// If no session with the specified account is found, the array remains unchanged.
    ///
    /// - Parameters:
    ///   - account: The account identifier of the session to replace.
    ///   - newSession: The `NKSession` instance that will replace the existing one.
    public func replace(account: String, with newSession: NKSession) {
        lock.perform {
            if let idx = array.firstIndex(where: { $0.account == account }) {
                array[idx] = newSession
            }
        }
    }

    // MARK: - Write Operations

    /// Appends a new session to the array.
    /// - Parameter element: The `NKSession` to append.
    public func append(_ element: NKSession) {
        lock.perform {
            array.append(element)
        }
    }

    /// Removes all sessions associated with the given account.
    /// - Parameter account: The account identifier string to remove sessions for.
    public func remove(account: String) {
        lock.perform {
            array.removeAll { $0.account == account }
        }
    }

    /// Removes all sessions from the array.
    public func removeAll() {
        lock.perform {
            array.removeAll()
        }
    }

    // MARK: - Subscript

    /// Accesses the session at a given index.
    /// - Parameter index: The index of the desired session.
    /// - Returns: A `NKSession` if the index is valid, otherwise `nil`.
    public subscript(index: Int) -> NKSession? {
        lock.perform {
            guard array.indices.contains(index) else { return nil }
            return array[index]
        }
    }
}
