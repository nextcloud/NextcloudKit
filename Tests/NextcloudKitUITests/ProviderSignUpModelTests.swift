// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
@testable import NextcloudKitUI
import Testing
import WebKit

///
/// Tests for the page load rules of ``ProviderSignUpModel``, which need no page to load.
///
@MainActor
@Suite
struct ProviderSignUpModelTests {
    // Nothing listens on port 1, so a load the model starts by itself goes nowhere.
    private let signUpURL = URL(string: "http://127.0.0.1:1/signup")! // swiftlint:disable:this force_unwrapping
    private let pageURL = URL(string: "https://provider.example.com/register")! // swiftlint:disable:this force_unwrapping

    private func makeModel() -> ProviderSignUpModel {
        ProviderSignUpModel(url: signUpURL, callbackScheme: "nc", userAgent: nil) { _ in }
    }

    @Test func requestHasTheAPIHeaderAndAShortTimeout() {
        let request = ProviderSignUpModel.request(for: pageURL)

        #expect(request.value(forHTTPHeaderField: "OCS-APIRequest") == "true")
        #expect(request.timeoutInterval == 20)
    }

    @Test func uncachedURLAddsAQueryItem() {
        let withQuery = URL(string: "https://nextcloud.com/signup-ios?lang=de")! // swiftlint:disable:this force_unwrapping

        #expect(ProviderSignUpModel.uncachedURL(pageURL).absoluteString == "https://provider.example.com/register?ocsapi=1")
        #expect(ProviderSignUpModel.uncachedURL(withQuery).absoluteString == "https://nextcloud.com/signup-ios?lang=de&ocsapi=1")
    }

    @Test func callbackURLFinishesInAnyLetterCase() {
        let model = makeModel()
        let callbackURL = URL(string: "NC://login/server:https://cloud.example.com&user:jane&password:secret")! // swiftlint:disable:this force_unwrapping

        #expect(model.policy(for: URLRequest(url: callbackURL), isMainFrame: false) == .finish(callbackURL))
    }

    @Test func pageLoadWithoutHeaderIsRepeatedOncePerPage() {
        let model = makeModel()
        let request = URLRequest(url: pageURL)

        #expect(model.policy(for: request, isMainFrame: true) == .reissue(ProviderSignUpModel.request(for: pageURL)))
        #expect(model.policy(for: request, isMainFrame: true) == .allow)

        model.webView(model.webView, didFinish: nil)

        #expect(model.policy(for: request, isMainFrame: true) == .reissue(ProviderSignUpModel.request(for: pageURL)))

        model.retry()

        #expect(model.policy(for: request, isMainFrame: true) == .reissue(ProviderSignUpModel.request(for: pageURL)))
    }

    @Test func pageLoadWithHeaderSubframesAndPostsPass() {
        let model = makeModel()
        var post = URLRequest(url: pageURL)
        post.httpMethod = "POST"

        #expect(model.policy(for: ProviderSignUpModel.request(for: pageURL), isMainFrame: true) == .allow)
        #expect(model.policy(for: URLRequest(url: pageURL), isMainFrame: false) == .allow)
        #expect(model.policy(for: post, isMainFrame: true) == .allow)
    }

    @Test func linksTheWebViewCannotShowOpenInTheirApp() {
        let model = makeModel()
        let mail = URL(string: "mailto:support@provider.example.com")! // swiftlint:disable:this force_unwrapping
        let blank = URL(string: "about:blank")! // swiftlint:disable:this force_unwrapping

        #expect(model.policy(for: URLRequest(url: mail), isMainFrame: true) == .openExternally(mail))
        #expect(model.policy(for: URLRequest(url: mail), isMainFrame: false) == .cancel)
        #expect(model.policy(for: URLRequest(url: blank), isMainFrame: false) == .allow)
    }

    @Test("Error statuses map to kinds whose texts fit a web page", arguments: [
        (408, NKError.Kind.timeout),
        (504, .timeout),
        (429, .rateLimited),
        (503, .unavailable),
        (500, .serverError),
        (501, .serverError),
        (599, .serverError),
        (403, .serverUnreachable),
        (404, .serverUnreachable)
    ])
    func statusMapping(statusCode: Int, kind: NKError.Kind) throws {
        let response = try #require(HTTPURLResponse(url: pageURL, statusCode: statusCode, httpVersion: nil, headerFields: nil))
        let error = try #require(ProviderSignUpModel.error(for: response, canShowMIMEType: true))

        #expect(error.errorCode == statusCode)
        #expect(error.kind == kind)
    }

    @Test func emptyAndUnshowableResponsesFail() throws {
        let page = try #require(HTTPURLResponse(url: pageURL, statusCode: 200, httpVersion: nil, headerFields: ["Content-Length": "120"]))
        let empty = try #require(HTTPURLResponse(url: pageURL, statusCode: 200, httpVersion: nil, headerFields: ["Content-Length": "0"]))

        #expect(ProviderSignUpModel.error(for: page, canShowMIMEType: true) == nil)
        #expect(ProviderSignUpModel.error(for: page, canShowMIMEType: false)?.kind == .invalidResponse)
        #expect(ProviderSignUpModel.error(for: empty, canShowMIMEType: true)?.kind == .invalidResponse)
    }

    @Test func webContentProcessEndReloadsOnceThenFails() {
        let model = makeModel()

        model.webViewWebContentProcessDidTerminate(model.webView)

        #expect(model.errorMessage == nil)

        model.webViewWebContentProcessDidTerminate(model.webView)

        #expect(model.errorMessage != nil)

        model.webView(model.webView, didFinish: nil)
        model.webViewWebContentProcessDidTerminate(model.webView)

        #expect(model.errorMessage == nil)
    }

    @Test func cancelledAndInterruptedLoadsShowNothing() {
        let model = makeModel()

        model.showLoadError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
        model.showLoadError(NSError(domain: "WebKitErrorDomain", code: 102))

        #expect(model.errorMessage == nil)

        model.showLoadError(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))

        #expect(model.errorMessage == NKError(errorCode: NSURLErrorTimedOut).localizedGenericMessage)
    }
}
