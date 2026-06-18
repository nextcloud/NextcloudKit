// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// The sheet wrapping ``WebView``.
///
struct WebSheet: ViewModifier {
    let onDismiss: () -> Void
    let userAgent: String?

    @Binding var initialURL: URL?
    @Binding var isPresented: Bool

    init(initialURL: Binding<URL?>, isPresented: Binding<Bool>, userAgent: String?, onDismiss: @escaping () -> Void) {
        self._initialURL = initialURL
        self._isPresented = isPresented
        self.onDismiss = onDismiss
        self.userAgent = userAgent
    }

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) {
            WebView(initialURL: $initialURL, userAgent: userAgent)
                .ignoresSafeArea()
        }
        #else
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            WebView(initialURL: $initialURL, userAgent: userAgent)
                .ignoresSafeArea()
                .frame(minWidth: 800, minHeight: 800)
        }
        #endif
    }
}

extension View {
    ///
    /// Present a ``WebView`` full screen (a sheet on macOS, where full screen covers are unavailable).
    ///
    /// See ``WebSheet`` for the implementation.
    ///
    func webSheet(initialURL: Binding<URL?>, isPresented: Binding<Bool>, userAgent: String?, onDismiss: @escaping () -> Void) -> some View {
        modifier(WebSheet(initialURL: initialURL, isPresented: isPresented, userAgent: userAgent, onDismiss: onDismiss))
    }
}

#Preview {
    ZStack {
        Color.blue
            .ignoresSafeArea()
    }
    .webSheet(initialURL: .constant(URL(string: "http://localhost:8080")), isPresented: .constant(true), userAgent: nil) {
        print("Web sheet dismissed!")
    }
}
