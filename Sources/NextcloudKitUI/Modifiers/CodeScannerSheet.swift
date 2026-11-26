// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import CodeScanner
import SwiftUI

///
/// A sheet with a camera view to scan QR codes for logging in.
/// It stays open and busy while a scanned code logs in, and closes on an error, which the login view shows.
///
struct CodeScannerSheet: ViewModifier {
    let model: LoginFlowModel
    @State private var isTorchOn = false

    func body(content: Content) -> some View {
        @Bindable var model = model

        return content.sheet(isPresented: $model.isPresentingCodeScanner) {
            model.codeScannerDidClose()
        } content: {
            NavigationStack {
                ZStack {
                    // One code per opening: an error closes the scanner.
                    CodeScannerView(codeTypes: [.qr], scanMode: .once, showViewfinder: true, isTorchOn: isTorchOn) { result in
                        model.handleQRCodeScan(result)
                    }

                    if model.isActive {
                        Color.black.opacity(0.5)

                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.large)
                            .tint(.white)
                            .accessibilityIdentifier("codeScannerProgress")
                    }
                }
                .ignoresSafeArea()
                .toolbarTitleDisplayMode(.inline)
                // The camera cannot scroll, so no scroll edge effect keeps the title readable over it.
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationTitle(String(localized: "Scan QR Code", bundle: .module, comment: "Navigation bar title"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            model.isPresentingCodeScanner = false
                        } label: {
                            Text("Cancel", bundle: .module, comment: "Button label")
                        }
                        .disabled(model.isActive)
                        .accessibilityIdentifier("cancelCodeScanner")
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isTorchOn.toggle()
                        } label: {
                            Label {
                                Text("Flashlight", bundle: .module, comment: "Accessibility label of the button which toggles the flashlight while scanning a QR code.")
                            } icon: {
                                Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            }
                        }
                        .disabled(model.isActive)
                        .accessibilityIdentifier("toggleTorch")
                    }
                }
            }
            .interactiveDismissDisabled(model.isActive)
        }
    }
}

extension View {
    ///
    /// A custom and specialized sheet to scan a QR code.
    ///
    /// See ``CodeScannerSheet`` for its implementation.
    ///
    func codeScannerSheet(model: LoginFlowModel) -> some View {
        modifier(CodeScannerSheet(model: model))
    }
}
