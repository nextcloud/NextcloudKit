// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WebKit

///
/// A generic web view which makes `WKWebView` available in SwiftUI which otherwise is not.
///
/// This is the base block for presentation of web-based content.
/// Be it a live website in form of a login process or just a static HTML document about legal matters shipped with the app bundle.
///
/// The web view is inspectable by Safari on connected developer machines for eased debugging.
///
/// All of the web view session data is not persistent.
///
public struct WebView: ViewRepresentable {
    /// Loaded once when the web view is created, so SwiftUI updates don't reload the page.
    let initialURL: URL?

    let userAgent: String?

    public init(initialURL: URL?, userAgent: String? = nil) {
        self.initialURL = initialURL
        self.userAgent = userAgent
    }

    func makeView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.isInspectable = true

        if let userAgent {
            webView.customUserAgent = userAgent
        }

        if let initialURL {
            webView.load(URLRequest(url: initialURL))
        }

        return webView
    }

    // MARK: - macOS

    #if os(macOS)

    public func makeNSView(context: Context) -> WKWebView {
        makeView()
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {}

    // MARK: - iOS

    #else

    public func makeUIView(context: Context) -> WKWebView {
        makeView()
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {}

    #endif
}

#Preview {
    // swiftlint:disable force_unwrapping
    WebView(initialURL: URL(string: "http://localhost:8080")!, userAgent: nil)
}
