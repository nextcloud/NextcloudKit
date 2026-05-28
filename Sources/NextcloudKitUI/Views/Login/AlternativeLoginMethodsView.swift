// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import CodeScanner
import SwiftUI

///
/// The QR code scan and shared account selection buttons in ``ServerAddressView``.
///
/// The visibility of the shared accounts button is determined based on the availability of shared accounts.
///
struct AlternativeLoginMethodsView: View {
    #if os(iOS)
    let scanHandler: (Result<ScanResult, ScanError>) -> Void
    #endif

    let selectionHandler: (SharedAccount) -> Void

    ///
    /// Whether the app found shared accounts or not.
    ///
    var sharedAccounts: [SharedAccount]

    #if os(iOS)
    ///
    /// State toggle for presenting the QR code scanner sheet.
    ///
    @State var isPresentingCodeScanner = false
    #endif

    ///
    /// State toggle whether the shared accounts have been suggested once during lifetime of this view.
    ///
    @State var hasSuggestedSharedAccounts = false

    ///
    /// State toggle for presenting the sheet to select accounts shared among apps of the same group.
    ///
    @State var isPresentingSharedAccounts = false

    #if os(iOS)
    init(sharedAccounts: [SharedAccount], scanHandler: @escaping (Result<ScanResult, ScanError>) -> Void, selectionHandler: @escaping (SharedAccount) -> Void) {
        self.sharedAccounts = sharedAccounts
        self.scanHandler = scanHandler
        self.selectionHandler = selectionHandler
    }
    #else
    init(sharedAccounts: [SharedAccount], selectionHandler: @escaping (SharedAccount) -> Void) {
        self.sharedAccounts = sharedAccounts
        self.selectionHandler = selectionHandler
    }
    #endif

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()

            HStack {
                Spacer()

                VStack(alignment: .leading) {
                    #if os(iOS) // Camera usually is available on iOS devices only.
                    Button {
                        isPresentingCodeScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)

                        Text(String(localized: "Scan QR Code", comment: "Button label"))
                    }
                    .padding()
                    .codeScannerSheet(isPresented: $isPresentingCodeScanner, scanHandler)
                    #endif

                    if sharedAccounts.isEmpty == false {
                        Button {
                            isPresentingSharedAccounts = true
                        } label: {
                            Image(systemName: "person.fill.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)

                            Text(String(localized: "Accounts from other Apps", comment: "Button label"))
                        }
                        .padding()
                        .sharedAccountsSheet(isPresented: $isPresentingSharedAccounts, sharedAccounts: sharedAccounts, selectionHandler: selectionHandler)
                        .onAppear {
                            if sharedAccounts.isEmpty == false && hasSuggestedSharedAccounts == false {
                                isPresentingSharedAccounts = true
                                hasSuggestedSharedAccounts = true
                            }
                        }
                    }
                }

                Spacer()
            }

            Spacer()
        }
    }
}
