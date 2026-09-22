// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// A new remote user account should be added locally in the persistence of the app.
///
/// This is called once the login flow (or a QR code scan) has produced credentials. The consumer
/// is responsible for persisting the account and any post-login bootstrap.
///
public typealias AddAccountHandler = (_ host: URL, _ name: String, _ password: String) -> Void

///
/// The full screen view in which a user enters the address of the server to log in on.
///
public struct ServerAddressView: View {
    let brandImage: Image
    var sharedAccounts: [SharedAccount]
    let userAgent: String?

    ///
    /// Create a new server address view.
    ///
    /// - Parameters:
    ///     - backgroundColor: The main theme color the view should use. Foreground color will be adapted automatically based on this.
    ///     - brandImage: The image to display on top of the server address view. Falls back to an SF Symbol placeholder in case of `nil`.
    ///     - sharedAccounts: Any shared accounts from the app group being available for selection and faster login.
    ///     - userAgent: An optional user agent string to override the one used by ``WKWebView``.
    ///     - addAccount: see ``AddAccountHandler``.
    ///
    public init(backgroundColor: Binding<Color>, brandImage: Image, sharedAccounts: [SharedAccount], userAgent: String? = nil, addAccount: @escaping AddAccountHandler) {
        self._backgroundColor = backgroundColor
        self.brandImage = brandImage
        self.sharedAccounts = sharedAccounts
        self.userAgent = userAgent
        self._model = State(initialValue: LoginFlowModel(userAgent: userAgent, addAccount: addAccount))
    }

    // MARK: - Environment

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    // MARK: - Bindings

    @Binding var backgroundColor: Color

    // MARK: - State

    ///
    /// The login flow engine. Owns the server address input, polling and web view state.
    ///
    @State private var model: LoginFlowModel

    #if os(iOS)
    ///
    /// State toggle for presenting the QR code scanner sheet.
    ///
    @State private var isPresentingCodeScanner = false
    #endif

    ///
    /// State toggle whether the shared accounts have been suggested once during lifetime of this view.
    ///
    @State private var hasSuggestedSharedAccounts = false

    ///
    /// State toggle for presenting the sheet to select accounts shared among apps of the same group.
    ///
    @State private var isPresentingSharedAccounts = false

    // MARK: - Implementation

    public var body: some View {
        @Bindable var model = model

        return NavigationStack {
            ZStack {
                backgroundColor

                VStack {
                    Spacer(minLength: 40)

                    // Brand image binding or fallback symbol.
                    brandImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(backgroundColor.readable)
                        .frame(width: 240, height: 120)
                        .padding(.vertical, 40)

                    // Some space between brand logo and server address field.
                    if verticalSizeClass == .regular {
                        Spacer()
                            .frame(height: 50)
                    }

                    // Container to add horizontal spacers for regular size classes.
                    HStack {
                        if horizontalSizeClass == .regular {
                            Spacer(minLength: 100)
                        }

                        // Container for the server address input and button.
                        HStack {
                            TextField(
                                text: $model.enteredServerAddress,
                                prompt: Text(verbatim: "https://example.org/").foregroundColor(backgroundColor.readable.opacity(0.5))
                            ) {
                                Text("Server Address", comment: "Label for text field.")
                            }
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .foregroundStyle(backgroundColor.readable)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            #endif
                            .onSubmit {
                                model.logIn()
                            }

                            if model.isActive {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(backgroundColor.readable)
                            } else {
                                Button {
                                    model.logIn()
                                } label: {
                                    #if !os(macOS)
                                    Image(systemName: "arrow.right")
                                    #else
                                    Image(systemName: "arrow.right.circle")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                    #endif
                                }
                                #if os(macOS)
                                .buttonStyle(.plain)
                                #endif
                            }
                        }
                        #if !os(macOS)
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(backgroundColor.readable, lineWidth: 1)
                        )
                        #endif

                        if horizontalSizeClass == .regular {
                            Spacer(minLength: 100)
                        }
                    }

                    Text("The address of your Nextcloud web interface when you open it in your browser.", comment: "Label below the server address field in the login view.")
                        .foregroundStyle(backgroundColor.readable)
                        .font(.footnote)
                        .padding(4)

                    Spacer()

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
                    .codeScannerSheet(isPresented: $isPresentingCodeScanner) {
                        model.handleQRCodeScan($0)
                    }
                    #endif

                    Spacer()
                }
                .disabled(model.isActive)
                .tint(backgroundColor.readable)
                .padding()
                .safeAreaPadding(.all)
            }
            .ignoresSafeArea()
            .toolbar {
                if sharedAccounts.isEmpty == false {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        sharedAccountsToolbarItem
                            .sharedBackgroundVisibility(.hidden)
                    } else {
                        sharedAccountsToolbarItem
                    }
                }
            }
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .sharedAccountsSheet(isPresented: $isPresentingSharedAccounts, sharedAccounts: sharedAccounts, selectionHandler: { model.selectSharedAccount($0) })
            .onAppear {
                if sharedAccounts.isEmpty == false && hasSuggestedSharedAccounts == false {
                    isPresentingSharedAccounts = true
                    hasSuggestedSharedAccounts = true
                }
            }
            .webSheet(initialURL: $model.loginAddress, isPresented: $model.isPresentingWebView, userAgent: userAgent, onDismiss: { model.cancel() })
            .alert(String(localized: "Login Failed", comment: "Alert title"), isPresented: $model.isPresentingAlert) {
                Button(role: .cancel) {
                    model.errorMessage = nil
                } label: {
                    Text("OK", comment: "Button label for error alert dismissal.")
                }
            } message: {
                Text(model.errorMessage ?? "?")
            }
        }
    }

    ///
    /// The toolbar entry point for accounts from other apps, as in the login view of the Files app.
    ///
    private var sharedAccountsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isPresentingSharedAccounts = true
            } label: {
                Label {
                    Text("Accounts from other Apps", comment: "Button label")
                } icon: {
                    Image(systemName: "person.badge.plus")
                }
            }
            .tint(backgroundColor.readable)
        }
    }
}

#if DEBUG

// swiftlint:disable force_unwrapping

#Preview("Without Shared Accounts") {
    let backgroundColor: Binding<Color> = .constant(.accentColor)
    let brandImage = Image(systemName: "questionmark.square.dashed")
    let sharedAccounts = [SharedAccount]()

    ServerAddressView(backgroundColor: backgroundColor, brandImage: brandImage, sharedAccounts: sharedAccounts) { _, _, _ in
        print("Add account!")
    }
}

#Preview("With Shared Accounts") {
    let backgroundColor: Binding<Color> = .constant(.accentColor)
    let brandImage = Image(systemName: "questionmark.square.dashed")
    let sharedAccounts = [
        SharedAccount("Jane Doe", on: URL(string: "http://localhost:8080")!, with: Image(systemName: "person.circle.fill"))
    ]

    ServerAddressView(backgroundColor: backgroundColor, brandImage: brandImage, sharedAccounts: sharedAccounts) { _, _, _ in
        print("Add account!")
    }
}

#endif
