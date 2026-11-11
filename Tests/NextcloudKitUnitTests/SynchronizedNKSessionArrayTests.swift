// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import NextcloudKit

@Suite("Synchronized session array")
struct SynchronizedNKSessionArrayTests {
    /// Regression test for a deadlock: a write left for a worker thread of a concurrent dispatch queue made the following read wait for that thread.
    /// The system may not start such a thread while every Swift concurrency thread is blocked, so the blocked tasks could not continue.
    @Test("A write and a following read finish while every other Swift concurrency thread is blocked.")
    func writeThenReadNeedsNoOtherThread() async {
        let blockerCount = ProcessInfo.processInfo.activeProcessorCount - 1
        let blockersArrived = DispatchSemaphore(value: 0)
        let releaseBlockers = DispatchSemaphore(value: 0)
        let writeStarted = DispatchSemaphore(value: 0)
        let readFinished = DispatchSemaphore(value: 0)
        let readFinishedInTime = DispatchSemaphore(value: 0)
        let sessions = SynchronizedNKSessionArray()

        // The watchdog runs outside the Swift concurrency thread pool, so it still releases the blockers when the read never finishes.
        Thread {
            if writeStarted.wait(timeout: .now() + 30) == .success, readFinished.wait(timeout: .now() + 5) == .success {
                readFinishedInTime.signal()
            }

            for _ in 0..<blockerCount {
                releaseBlockers.signal()
            }
        }.start()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<blockerCount {
                group.addTask {
                    blockersArrived.signal()
                    Self.block(on: releaseBlockers)
                }
            }

            group.addTask {
                for _ in 0..<blockerCount {
                    Self.block(on: blockersArrived)
                }

                writeStarted.signal()
                sessions.removeAll()
                _ = sessions.count
                readFinished.signal()
            }
        }

        #expect(Self.isSignaled(readFinishedInTime), "The read after the write did not finish within 5 seconds.")
    }

    /// Blocks the calling Swift concurrency thread on purpose, which an async context does not allow directly.
    private static func block(on semaphore: DispatchSemaphore) {
        semaphore.wait()
    }

    /// Returns whether `semaphore` has been signaled, without waiting.
    private static func isSignaled(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now()) == .success
    }
}
