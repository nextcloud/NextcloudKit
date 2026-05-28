// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import CodeScanner
import SwiftUI

///
/// A new remote user account should be added locally in the persistence of the app.
///
/// This method is required, in example by the QR code scan. The scan happens in domain of this package and circumvents the polling logic of the hosting app.
///
public typealias AddAccountHandler = (_ host: URL, _ name: String, _ password: String) -> Void

///
/// The handler should start polling for the login flow status.
///
/// - Parameters:
///     - url: The address of the server on which a login flow is to be started.
///     - dismiss: The handler to call when the login user interface should be dismissed.
///
/// - Returns: The delegate must return the address on which the user should enter the login flow which then will be navigated to in the web view of this package.
///
public typealias BeginPollingHandler = (_ url: URL, _ dismiss: @MainActor @Sendable @escaping () -> Void) async throws -> URL

///
/// The login process was cancelled. This can happen intentionally by the user dismissing the related views. The polling can be stopped.
///
/// - Parameters:
///     - token: The polling token the login flow is identified by uniquely.
///
public typealias CancelPollingHandler = () -> Void

///
/// The full screen view in which a user enters the address of the server to log in on.
///
public struct ServerAddressView: View, QRCodeParsing, URLSanitizing {
    let addAccount: AddAccountHandler
    let beginPolling: BeginPollingHandler
    let cancelPolling: CancelPollingHandler
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
    ///     - beginPolling: see ``BeginPollingHandler``.
    ///     - cancelPolling: see ``CancelPollingHandler``.
    ///
    public init(backgroundColor: Binding<Color>, brandImage: Image, sharedAccounts: [SharedAccount], userAgent: String? = nil, addAccount: @escaping AddAccountHandler, beginPolling: @escaping BeginPollingHandler, cancelPolling: @escaping CancelPollingHandler) {
        self._backgroundColor = backgroundColor
        self.addAccount = addAccount
        self.beginPolling = beginPolling
        self.cancelPolling = cancelPolling
        self.brandImage = brandImage
        self.sharedAccounts = sharedAccounts
        self.userAgent = userAgent
    }

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    // MARK: - Bindings

    @Binding var backgroundColor: Color

    // MARK: - State

    ///
    /// The unsanitized user input.
    ///
    @State var enteredServerAddress = ""

    ///
    /// Message to display in case of error.
    ///
    @State var errorMessage: String?

    ///
    /// Whether there currently is an activity which requires disabling the user interface.
    ///
    @State var isActive = false

    ///
    /// State toggle for presenting the error alert.
    ///
    @State var isPresentingAlert = false

    ///
    /// State toggle for presenting the web view sheet.
    ///
    @State var isPresentingWebView = false

    ///
    /// The login address acquired by the server through the login flow API.
    ///
    @State var loginAddress: URL?

    // MARK: - Implementation

    public var body: some View {
        ZStack {
            backgroundColor

            VStack {
                Spacer(minLength: 40)

                // Brand image binding or fallback symbol.
                brandImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(backgroundColor.readable)
                    .frame(minHeight: 100)
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
                            text: $enteredServerAddress,
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
                            sanitizeEnteredServerAddressAndLogIn()
                        }

                        if isActive {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(backgroundColor.readable)
                        } else {
                            Button {
                                sanitizeEnteredServerAddressAndLogIn()
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

                // Buttons for QR code and shared accounts.
                #if os(iOS)
                AlternativeLoginMethodsView(sharedAccounts: sharedAccounts, scanHandler: handleQRCodeScan, selectionHandler: handleSharedAccountSelection)
                #else
                AlternativeLoginMethodsView(sharedAccounts: sharedAccounts, selectionHandler: handleSharedAccountSelection)
                #endif

                Spacer()
            }
            .disabled(isActive)
            .tint(backgroundColor.readable)
            .padding()
            .safeAreaPadding(.all)
        }
        .ignoresSafeArea()
        .webSheet(initialURL: $loginAddress, isPresented: $isPresentingWebView, userAgent: userAgent, onDismiss: endWebView)
        .alert(String(localized: "Login Failed", comment: "Alert title"), isPresented: $isPresentingAlert) {
            Button(role: .cancel) {
                errorMessage = nil
            } label: {
                Text("OK", comment: "Button label for error alert dismissal.")
            }
        } message: {
            Text(errorMessage ?? "?")
        }
    }

    // MARK: - Logic

    #if os(iOS)
    func handleQRCodeScan(_ result: Result<ScanResult, ScanError>) {
        switch result {
            case .success(let result):
                do {
                    let (name, password, host) = try parse(result.string)
                    addAccount(host, name, password)
                } catch {
                    errorMessage = error.localizedDescription
                    isPresentingAlert = true
                    return
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
        }
    }
    #endif

    func handleSharedAccountSelection(_ account: SharedAccount) {
        enteredServerAddress = account.host.absoluteString
        sanitizeEnteredServerAddressAndLogIn(user: account.name)
    }

    ///
    /// Clean up the received user input and dispatch the login flow.
    ///
    /// - Parameters:
    ///     - user: An optional user name to fill out automatically in the web user interface during the login.
    ///
    func sanitizeEnteredServerAddressAndLogIn(user: String? = nil) {
        guard enteredServerAddress.trimmingCharacters(in: .whitespaces).isEmpty == false else {
            return
        }

        guard let sanitizedServerAddress = sanitize(enteredServerAddress) else {
            errorMessage = String(localized: "The entered server address is invalid.", comment: "This is an error message.")
            isPresentingAlert = true
            return
        }

        Task {
            do {
                var url = try await beginPolling(sanitizedServerAddress) {
                    isPresentingWebView = false
                    dismiss()
                }

//                Temporary disabled until https://github.com/nextcloud/server/issues/59874 is resolved.
//                if let user {
//                    url.append(queryItems: [URLQueryItem(name: "user", value: user)])
//                }

                beginWebView(url)
            } catch {
                endLogin(error)
            }
        }
    }

    func beginWebView(_ url: URL) {
        self.loginAddress = url
        isPresentingWebView = true
    }

    ///
    /// Dismisses the sheet with the web view.
    ///
    /// Multiple paths can lead to here. In example:
    ///
    /// - The user dismisses the sheet without logging in.
    /// - The login completed successfully.
    ///
    func endWebView() {
        cancelPolling()

        isActive = false
        isPresentingWebView = false
    }

    ///
    /// Completing the login process regardless of success or failure.
    ///
    func endLogin(_ error: Error? = nil) {
        endWebView()

        if let error {
            errorMessage = error.localizedDescription
            isPresentingAlert = true
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
    } beginPolling: { _, _ in
        print("Begin polling!")
        return URL(string: "about:blank")!
    } cancelPolling: {
        print("Cancel polling!")
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
    } beginPolling: { _, _ in
        print("Begin polling!")
        return URL(string: "about:blank")!
    } cancelPolling: {
        print("Cancel polling!")
    }
}

#endif
