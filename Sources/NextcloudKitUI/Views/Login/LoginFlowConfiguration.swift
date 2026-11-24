// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import SwiftUI

///
/// Host app options for ``ServerAddressView``. The defaults reproduce the plain login screen.
///
public struct LoginFlowConfiguration: Sendable {
    ///
    /// A server the user may pick instead of typing an address.
    ///
    public struct Server: Identifiable, Hashable, Sendable {
        public let name: String
        public let url: URL

        public var id: URL {
            url
        }

        public init(name: String, url: URL) {
            self.name = name
            self.url = url
        }
    }

    ///
    /// How the login flow continues after the server status check failed.
    ///
    public enum Recovery: Sendable {
        /// Start over with this address, e.g. after trusting a certificate or falling back to `http`.
        case retry(URL)

        /// End the login silently, e.g. when the user declined.
        case cancel

        /// Show the error in the login view.
        case presentError
    }

    public typealias ServerErrorHandler = @MainActor @Sendable (_ error: NKError, _ serverURL: URL) async -> Recovery
    public typealias CancelHandler = @MainActor @Sendable () -> Void

    ///
    /// Text and tint color on top of the background. Derived from the background color when `nil`.
    ///
    public var foregroundColor: Color?

    ///
    /// Replaces the hint below the server address field.
    ///
    public var serverAddressDescription: String?

    ///
    /// Replaces the label of the server picker shown for ``enforcedServers`` until one is picked.
    ///
    public var enforcedServersPrompt: String?

    ///
    /// Prefills the server address field.
    ///
    public var initialServerAddress: String?

    ///
    /// Starts the login for ``initialServerAddress`` when the view appears, e.g. for a server the user just signed up on.
    ///
    public var startsLoginOnAppear = false

    public var isServerAddressEditable = true

    ///
    /// When not empty, a picker over these servers replaces the server address field.
    ///
    public var enforcedServers: [Server] = []

    ///
    /// Whether an explicit `http` scheme typed by the user is replaced with `https`.
    ///
    public var upgradesInsecureHTTP = false

    ///
    /// The scheme of login QR codes and of the URL the login page redirects to, without `://`.
    ///
    public var loginURLScheme = "nc"

    ///
    /// Set to `false` when the view is pushed onto an existing navigation stack, so its toolbar items join that navigation bar.
    ///
    public var embedsNavigationStack = true

    public var showsCancelButton = false

    ///
    /// Called after the cancel button ended the login. The host dismisses the view.
    ///
    public var onCancel: CancelHandler?

    ///
    /// Lets the host resolve a failed server check, e.g. with its own certificate trust prompt. Without it, the error is shown.
    ///
    public var onServerError: ServerErrorHandler?

    ///
    /// Ends polling for the login result after this time. Matches the lifetime of a login flow token on the server.
    ///
    public var pollingTimeout: Duration = .seconds(20 * 60)

    public init() {}
}
