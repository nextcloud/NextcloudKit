// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// The sign-up page of a provider. It closes by itself once the sign-up reached the login callback URL.
///
struct ProviderSignUpView: View {
    let model: ProviderSignUpModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            page
                // Colored like the page, as in Safari, since the bar does not track the web view's scrolling.
                .toolbarBackground(pageColor ?? Color(uiColor: .systemBackground), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(pageColor.map { $0.readable == .white ? .dark : .light }, for: .navigationBar)
        }
        .onAppear {
            model.start()
        }
    }

    private var pageColor: Color? {
        model.pageColor.map { Color(uiColor: $0) }
    }

    private var page: some View {
        ZStack {
            WebView(webView: model.webView)
                .ignoresSafeArea(edges: .bottom)

            if let errorMessage = model.errorMessage {
                ContentUnavailableView {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(String(localized: "Retry", bundle: .module)) {
                        model.retry()
                    }
                    .accessibilityIdentifier("retryProviderSignUp")
                }
                .background(Color(uiColor: .systemBackground))
            } else if model.isLoading {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .navigationTitle(model.url.host ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel", bundle: .module, comment: "Button label")
                }
                .accessibilityIdentifier("cancelProviderSignUp")
            }
        }
    }
}
