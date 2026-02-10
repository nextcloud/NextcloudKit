// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

/// An operation handle that exposes the underlying Alamofire DataRequest and URLSessionTask
/// as soon as they are created, allowing clients to cancel an in-flight operation or observe
/// its lifecycle in a thread-safe way.
///
/// NKOperationHandle is an actor, so interactions are serialized and safe across concurrency domains.
/// Typical usage:
///   - Pass an instance to APIs that create a network request.
///   - The API will call `set(request:)` and/or `set(task:)` when the request/task is created.
///   - Call `cancel()` at any time to stop the operation.
///   - Optionally call `clear()` to drop stored references.
///
/// Notes:
///   - `cancel()` prefers canceling the Alamofire DataRequest when available; otherwise it falls back
///     to canceling the underlying URLSessionTask.
///   - `clear()` is optional and can be used to explicitly release references once an operation completes.
public actor NKOperationHandle {
    private(set) var request: DataRequest?
    private(set) var task: URLSessionTask?

    public init() {}

    public func set(request: DataRequest) { self.request = request }
    public func set(task: URLSessionTask) { self.task = task }

    public func cancel() {
        if let request = request {
            request.cancel()
        } else {
            task?.cancel()
        }
    }

    public func clear() {
        request = nil
        task = nil
    }
}
