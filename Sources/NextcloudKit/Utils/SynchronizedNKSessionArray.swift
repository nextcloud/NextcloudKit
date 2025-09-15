// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A thread-safe container for managing an array of `NKSession` instances.
///
/// Internally uses a concurrent `DispatchQueue` with barrier writes to ensure safe concurrent access and mutation.
/// Conforms to `@unchecked Sendable` for Swift 6 compatibility.
public final class SynchronizedNKSessionArray: @unchecked Sendable {

    // MARK: - Internal Storage

    /// Internal storage for the session array.
    private var array: [NKSession]

    /// Dispatch queue used for synchronizing access to the array.
    private let queue: DispatchQueue

    // MARK: - Initialization

    /// Initializes a new synchronized array with optional initial content.
    /// - Parameter initial: An initial array of `NKSession` to populate the container with.
    public init(_ initial: [NKSession] = []) {
        self.array = initial
        self.queue = DispatchQueue(label: "com.nextcloud.SynchronizedNKSessionArray", attributes: .concurrent)
    }

    // MARK: - Read Operations

    /// Returns the number of sessions currently stored.
    public var count: Int {
        queue.sync { array.count }
    }

    /// Returns a Boolean value indicating whether the array is empty.
    public var isEmpty: Bool {
        queue.sync { array.isEmpty }
    }

    /// Returns a snapshot of all stored sessions.
    public var all: [NKSession] {
        queue.sync { array }
    }

    /// Calls the given closure on each session in the array, in order.
    /// - Parameter body: A closure that takes a `NKSession` as a parameter.
    public func forEach(_ body: (NKSession) -> Void) {
        queue.sync {
            array.forEach(body)
        }
    }

    /// Returns the first session matching a given account string.
    /// - Parameter account: The account identifier string to match.
    /// - Returns: A `NKSession` instance if found, otherwise `nil`.
    public func session(forAccount account: String) -> NKSession? {
        queue.sync {
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
        queue.sync {
            array.contains(where: { $0.account == account })
        }
    }

    /// Replaces the first stored session that matches the given account identifier with a new session.
    ///
    /// This method performs the replacement in a thread-safe manner using a barrier write
    /// on the internal concurrent queue. If no session with the specified account is found,
    /// the array remains unchanged.
    ///
    /// - Parameters:
    ///   - account: The account identifier of the session to replace.
    ///   - newSession: The `NKSession` instance that will replace the existing one.
    public func replace(account: String, with newSession: NKSession) {
        queue.async(flags: .barrier) {
            if let idx = self.array.firstIndex(where: { $0.account == account }) {
                self.array[idx] = newSession
            }
        }
    }

    // MARK: - Write Operations

    /// Appends a new session to the array.
    /// - Parameter element: The `NKSession` to append.
    public func append(_ element: NKSession) {
        queue.async(flags: .barrier) {
            self.array.append(element)
        }
    }

    /// Removes all sessions associated with the given account.
    /// - Parameter account: The account identifier string to remove sessions for.
    public func remove(account: String) {
        queue.async(flags: .barrier) {
            self.array.removeAll { $0.account == account }
        }
    }

    /// Removes all sessions from the array.
    public func removeAll() {
        queue.async(flags: .barrier) {
            self.array.removeAll()
        }
    }

    // MARK: - Subscript

    /// Accesses the session at a given index.
    /// - Parameter index: The index of the desired session.
    /// - Returns: A `NKSession` if the index is valid, otherwise `nil`.
    public subscript(index: Int) -> NKSession? {
        queue.sync {
            guard array.indices.contains(index) else { return nil }
            return array[index]
        }
    }
}
