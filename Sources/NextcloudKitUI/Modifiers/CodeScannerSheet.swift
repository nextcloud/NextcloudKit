// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import CodeScanner
import SwiftUI

#if os(iOS)

///
/// A sheet with a camera view to scan QR codes for logging in.
/// Includes toolbar configuration and its appearance.
///
struct CodeScannerSheet: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    @Binding var isPresentingCodeScanner: Bool
    let completionHandler: (Result<ScanResult, ScanError>) -> Void

    init(isPresented: Binding<Bool>, _ completionHandler: @escaping (Result<ScanResult, ScanError>) -> Void) {
        self._isPresentingCodeScanner = isPresented
        self.completionHandler = completionHandler
    }

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresentingCodeScanner) {
            NavigationStack {
                CodeScannerView(codeTypes: [.qr], scanMode: .once, showViewfinder: true, completion: completionHandler)
                .ignoresSafeArea()
                .toolbarTitleDisplayMode(.inline)
                .navigationTitle(String(localized: "Scan QR Code", comment: "Navigation bar title"))
            }
        }
    }
}

extension View {
    ///
    /// A custom and specialized sheet to scan a QR code.
    ///
    /// See ``CodeScannerSheet`` for its implementation.
    ///
    func codeScannerSheet(isPresented: Binding<Bool>, _ completionHandler: @escaping (Result<ScanResult, ScanError>) -> Void) -> some View {
        modifier(CodeScannerSheet(isPresented: isPresented, completionHandler))
    }
}

#endif
