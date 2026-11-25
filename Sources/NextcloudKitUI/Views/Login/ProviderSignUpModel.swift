// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import SwiftUI
import UIKit
@preconcurrency import WebKit

///
/// Loads the sign-up page of a provider and reports the login callback URL the sign-up ends on.
///
/// A web view instead of a browser session, because the sign-up page only hands over credentials to page loads with the OCS API header.
///
@MainActor
@Observable
final class ProviderSignUpModel: NSObject, Identifiable, WKNavigationDelegate {
    ///
    /// What happens to a page load the web view is about to start.
    ///
    enum Policy: Equatable {
        case allow
        case cancel

        /// The sign-up ended on the login callback URL.
        case finish(URL)

        /// The page load starts again with this request, which has the OCS API header.
        case reissue(URLRequest)

        /// A link the web view cannot show, such as `mailto:`, opens in its app.
        case openExternally(URL)
    }

    /// Schemes the web view shows itself.
    private static let webSchemes: Set<String> = ["http", "https", "about", "data", "blob"]

    static let apiHeader = "OCS-APIRequest"

    let url: URL
    let webView: WKWebView

    /// Whether the web view is loading a page.
    private(set) var isLoading = false

    /// Why the page did not load. Shown instead of the page.
    private(set) var errorMessage: String?

    /// The color the page asks for, as Safari colors its bar: its theme color, otherwise its background.
    private(set) var pageColor: UIColor?

    @ObservationIgnored private let callbackScheme: String
    @ObservationIgnored private let onCallback: @MainActor (URL) -> Void
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var reissuedURLs: Set<URL> = []
    @ObservationIgnored private var requestedURL: URL?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var hasReloadedAfterTermination = false
    @ObservationIgnored private var isFinished = false

    ///
    /// - Parameters:
    ///     - url: The sign-up page.
    ///     - callbackScheme: The scheme of the login callback URL, without `://`.
    ///     - userAgent: An optional user agent for the page loads.
    ///     - onCallback: Called once with the login callback URL.
    ///
    init(url: URL, callbackScheme: String, userAgent: String?, onCallback: @escaping @MainActor (URL) -> Void) {
        self.url = url
        self.callbackScheme = callbackScheme.lowercased()
        self.onCallback = onCallback

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)

        if let userAgent {
            webView.customUserAgent = userAgent
        }

        super.init()

        webView.navigationDelegate = self

        observations = [
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.isLoading = webView.isLoading
                }
            },
            webView.observe(\.themeColor, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.pageColor = webView.themeColor ?? webView.underPageBackgroundColor
                }
            }
        ]
    }

    // MARK: - Loading

    ///
    /// Load the sign-up page, once.
    ///
    func start() {
        guard hasStarted == false else { return }

        hasStarted = true
        webView.load(Self.request(for: Self.uncachedURL(url)))
    }

    ///
    /// Load the page that failed again, or the sign-up page when none was requested yet.
    ///
    func retry() {
        errorMessage = nil
        reissuedURLs.removeAll()
        webView.load(Self.request(for: requestedURL ?? Self.uncachedURL(url)))
    }

    ///
    /// nextcloud.com serves its sign-up page from a cache that ignores the header, unless the address has a query.
    ///
    static func uncachedURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }

        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "ocsapi", value: "1")]

        return components.url ?? url
    }

    ///
    /// Fails after 20 seconds without data instead of a minute, so an unreachable server is reported soon.
    ///
    static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("true", forHTTPHeaderField: apiHeader)

        return request
    }

    // MARK: - Decisions

    func policy(for request: URLRequest, isMainFrame: Bool) -> Policy {
        guard let url = request.url, let scheme = url.scheme?.lowercased() else { return .cancel }

        if scheme == callbackScheme {
            return .finish(url)
        }

        guard Self.webSchemes.contains(scheme) else {
            return isMainFrame ? .openExternally(url) : .cancel
        }

        if isMainFrame, request.httpMethod == "GET" {
            // Redirects and links lose the header, so such page loads are started again with it, once per page.
            if request.value(forHTTPHeaderField: Self.apiHeader) == nil, reissuedURLs.insert(url).inserted {
                return .reissue(Self.request(for: url))
            }

            requestedURL = url
        }

        return .allow
    }

    ///
    /// Error pages and empty responses would otherwise load as if nothing went wrong.
    ///
    /// - Returns: Why the page must not be shown, or `nil` to show it.
    ///
    static func error(for response: URLResponse, canShowMIMEType: Bool) -> NKError? {
        if let response = response as? HTTPURLResponse, response.statusCode >= 400 {
            return error(forStatusCode: response.statusCode)
        }

        if canShowMIMEType == false || response.expectedContentLength == 0 {
            return .invalidResponseError
        }

        return nil
    }

    ///
    /// Picks a kind whose NextcloudKit text fits a web page, unlike the file-related ones for 403 or 404.
    ///
    static func error(forStatusCode statusCode: Int) -> NKError {
        let kind: NKError.Kind

        switch statusCode {
        case 408, 504:
            kind = .timeout
        case 429:
            kind = .rateLimited
        case 503:
            kind = .unavailable
        case 500, 501, 505...599:
            kind = .serverError
        default:
            kind = .serverUnreachable
        }

        return NKError(errorCode: statusCode, errorDescription: HTTPURLResponse.localizedString(forStatusCode: statusCode), kind: kind)
    }

    func pageDidFinish() {
        reissuedURLs.removeAll()
        hasReloadedAfterTermination = false
    }

    func webContentProcessDidTerminate() {
        // WebKit stops reloading by itself once the delegate handles this, so reload once and report a repeat.
        guard hasReloadedAfterTermination else {
            hasReloadedAfterTermination = true
            retry()
            return
        }

        showLoadError(NKError(errorCode: WKError.Code.webContentProcessTerminated.rawValue, errorDescription: "Web content process terminated", kind: .unknown))
    }

    func showLoadError(_ error: Error) {
        // Page loads this model replaces end as interrupted or cancelled.
        let nsError = error as NSError
        let isInterrupted = nsError.domain == "WebKitErrorDomain" && nsError.code == 102
        let nkError = error as? NKError ?? NKError(error: error)

        guard isFinished == false, isInterrupted == false, nkError.kind != .cancelled else { return }

        errorMessage = nkError.localizedGenericMessage
    }

    private func finish(callbackURL: URL) {
        guard isFinished == false else { return }

        isFinished = true
        onCallback(callbackURL)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        switch policy(for: navigationAction.request, isMainFrame: navigationAction.targetFrame?.isMainFrame == true) {
        case .allow:
            decisionHandler(.allow)
        case .cancel:
            decisionHandler(.cancel)
        case .finish(let callbackURL):
            decisionHandler(.cancel)
            finish(callbackURL: callbackURL)
        case .reissue(let request):
            decisionHandler(.cancel)
            webView.load(request)
        case .openExternally(let url):
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame,
              let error = Self.error(for: navigationResponse.response, canShowMIMEType: navigationResponse.canShowMIMEType) else {
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)
        showLoadError(error)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard let url = webView.url, url.scheme?.lowercased() == callbackScheme else { return }

        finish(callbackURL: url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageColor = webView.themeColor ?? webView.underPageBackgroundColor
        pageDidFinish()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webContentProcessDidTerminate()
    }
}
