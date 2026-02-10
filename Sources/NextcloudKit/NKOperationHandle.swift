// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

/// An operation handle that exposes the underlying Alamofire DataRequest and URLSessionTask
/// as soon as they are created, allowing clients to cancel an in-flight operation, observe
/// its lifecycle, and react to state changes via an async events stream.
///
/// Concurrency & thread-safety:
/// NKOperationHandle is an actor, so interactions are serialized and safe across concurrency domains.
///
/// Features:
/// - Store and expose the underlying `DataRequest` and `URLSessionTask`.
/// - Cancel the operation at any time using `cancel()` (prefers `DataRequest.cancel()`; falls back to `URLSessionTask.cancel()`).
/// - Observe lifecycle events with `events()` returning `AsyncStream<NKOperationEvent>`.
///   Emitted events include:
///   - `.didSetRequest(DataRequest)` when the request is created and stored
///   - `.didSetTask(URLSessionTask)` when the task is created and stored
///   - `.didCancel` after `cancel()` is invoked
///   - `.didClear` when references are cleared via `clear()`
/// - Check whether an operation is currently active using `isActive()`.
/// - Explicitly release stored references using `clear()`.
///
/// Typical usage:
/// ```swift
/// let handle = NKOperationHandle()
/// Task {
///     for await event in await handle.events() {
///         switch event {
///         case .didSetTask(let task):
///             print("Task available:", task)
///         case .didSetRequest(let request):
///             print("Request available:", request)
///         case .didCancel:
///             print("Operation cancelled")
///         case .didClear:
///             print("Handle cleared")
///         }
///     }
/// }
/// // Pass `handle` to an API that creates a network request.
/// // The API will call `set(request:)` and/or `set(task:)` when available.
/// // You can cancel at any time:
/// await handle.cancel()
/// ```
///
/// Notes:
/// - The events stream is created lazily the first time `events()` is called and is finished in `clear()`.
/// - If you don't need event observation, you can ignore `events()` and use only `cancel()`/`isActive()`.
public actor NKOperationHandle {
    private(set) var request: DataRequest?
    private(set) var task: URLSessionTask?

    public enum NKOperationEvent {
        case didSetRequest(DataRequest)
        case didSetTask(URLSessionTask)
        case didCancel
        case didClear
    }

    private var eventsStream: AsyncStream<NKOperationEvent>?
    private var eventsContinuation: AsyncStream<NKOperationEvent>.Continuation?

    public init() {}

    public func events() -> AsyncStream<NKOperationEvent> {
        if let eventsStream { return eventsStream }
        let (stream, continuation) = AsyncStream<NKOperationEvent>.makeStream()
        self.eventsStream = stream
        self.eventsContinuation = continuation
        return stream
    }

    public func set(request: DataRequest) {
        self.request = request
        eventsContinuation?.yield(.didSetRequest(request))
    }
    public func set(task: URLSessionTask) {
        self.task = task
        eventsContinuation?.yield(.didSetTask(task))
    }

    public func cancel() {
        if let request = request {
            request.cancel()
        } else {
            task?.cancel()
        }
        eventsContinuation?.yield(.didCancel)
    }

    public func clear() {
        eventsContinuation?.yield(.didClear)
        request = nil
        task = nil
        eventsContinuation?.finish()
        eventsContinuation = nil
        eventsStream = nil
    }

    public func isActive() -> Bool {
        return request != nil || task != nil
    }
}

