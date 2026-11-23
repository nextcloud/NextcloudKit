// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import AuthenticationServices
import SwiftUI

///
/// A new remote user account should be added locally in the persistence of the app.
///
/// This is called once the login flow (or a QR code scan) has produced credentials. The consumer
/// is responsible for persisting the account and any post-login bootstrap. The view stays busy
/// until this returns and shows a thrown error.
///
public typealias AddAccountHandler = @MainActor (_ host: URL, _ name: String, _ password: String) async throws -> Void

///
/// The full screen view in which a user enters the address of the server to log in on.
///
public struct ServerAddressView: View {
    let brandImage: Image
    var sharedAccounts: [SharedAccount]
    let configuration: LoginFlowConfiguration

    ///
    /// Create a new server address view.
    ///
    /// - Parameters:
    ///     - backgroundColor: The main theme color the view should use. Foreground color will be adapted automatically based on this.
    ///     - brandImage: The image to display on top of the server address view.
    ///     - sharedAccounts: Any shared accounts from the app group being available for selection and faster login.
    ///     - userAgent: An optional user agent for server requests.
    ///     - configuration: See ``LoginFlowConfiguration``.
    ///     - addAccount: see ``AddAccountHandler``.
    ///
    public init(backgroundColor: Binding<Color>, brandImage: Image, sharedAccounts: [SharedAccount], userAgent: String? = nil, configuration: LoginFlowConfiguration = LoginFlowConfiguration(), addAccount: @escaping AddAccountHandler) {
        self._backgroundColor = backgroundColor
        self.brandImage = brandImage
        self.sharedAccounts = sharedAccounts
        self.configuration = configuration
        self._model = State(initialValue: LoginFlowModel(userAgent: userAgent, configuration: configuration, addAccount: addAccount))
    }

    // MARK: - Environment

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    // MARK: - Bindings

    @Binding var backgroundColor: Color

    // MARK: - State

    ///
    /// The login flow engine. Owns the server address input, polling and web view state.
    ///
    @State private var model: LoginFlowModel

    ///
    /// State toggle whether the shared accounts have been suggested once during lifetime of this view.
    ///
    @State private var hasSuggestedSharedAccounts = false

    ///
    /// State toggle for presenting the sheet to select accounts shared among apps of the same group.
    ///
    @State private var isPresentingSharedAccounts = false

    ///
    /// The server picked from ``LoginFlowConfiguration/enforcedServers``.
    ///
    @State private var selectedServer: LoginFlowConfiguration.Server?

    private var foregroundColor: Color {
        configuration.foregroundColor ?? backgroundColor.readable
    }

    // MARK: - Implementation

    public var body: some View {
        if configuration.embedsNavigationStack {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        @Bindable var model = model

        return ZStack {
            backgroundColor

            VStack {
                Spacer(minLength: 40)

                brandImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(foregroundColor)
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
                        if configuration.enforcedServers.isEmpty {
                            serverAddressField
                        } else {
                            enforcedServersPicker
                        }

                        if model.isActive {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(foregroundColor)
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
                            .accessibilityLabel(Text("Log in", bundle: .module, comment: "Accessibility label of the button which starts the login."))
                            .accessibilityIdentifier("submitServerAddress")
                        }
                    }
                    #if !os(macOS)
                    .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(foregroundColor, lineWidth: 1)
                    )
                    #endif

                    if horizontalSizeClass == .regular {
                        Spacer(minLength: 100)
                    }
                }

                Group {
                    if let serverAddressDescription = configuration.serverAddressDescription {
                        Text(verbatim: serverAddressDescription)
                    } else {
                        Text("The address of your Nextcloud web interface when you open it in your browser.", bundle: .module, comment: "Label below the server address field in the login view.")
                    }
                }
                .foregroundStyle(foregroundColor)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(4)

                Spacer()

                #if os(iOS) // Camera usually is available on iOS devices only.
                Button {
                    model.presentCodeScanner()
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)

                    Text(String(localized: "Scan QR Code", bundle: .module, comment: "Button label"))
                }
                .padding()
                .accessibilityIdentifier("scanQRCode")
                #endif

                Spacer()
            }
            .disabled(model.isActive)
            .tint(foregroundColor)
            .padding()
            .safeAreaPadding(.all)
        }
        .ignoresSafeArea()
        .toolbar {
            if configuration.showsCancelButton {
                cancelToolbarItem
            }

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
        #if os(iOS)
        // Outside the form, whose disabled state and brand tint would carry over into the sheet and its alert.
        .codeScannerSheet(model: model)
        #endif
        .onAppear {
            if sharedAccounts.isEmpty == false && hasSuggestedSharedAccounts == false {
                isPresentingSharedAccounts = true
                hasSuggestedSharedAccounts = true
            }
        }
        .task(id: model.isPresentingLoginPage) {
            // Clearing the flag cancels this task, which closes the browser sheet.
            guard model.isPresentingLoginPage, let loginAddress = model.loginAddress else { return }

            await model.presentLoginPage(loginAddress, using: webAuthenticationSession)
        }
        // The QR code scanner shows its own errors while it is open.
        .loginFlowAlert(model: model, isPresented: Binding {
            model.isPresentingAlert && model.isPresentingCodeScanner == false
        } set: {
            model.isPresentingAlert = $0
        })
    }

    private var serverAddressField: some View {
        @Bindable var model = model

        return TextField(
            text: $model.enteredServerAddress,
            prompt: Text(verbatim: "https://example.org/").foregroundColor(foregroundColor.opacity(0.5))
        ) {
            Text("Server Address", bundle: .module, comment: "Label for text field.")
        }
        .textContentType(.URL)
        .autocorrectionDisabled()
        #if os(iOS)
        .foregroundStyle(foregroundColor)
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
        .submitLabel(.done)
        #endif
        .onSubmit {
            model.logIn()
        }
        .disabled(configuration.isServerAddressEditable == false)
        .opacity(configuration.isServerAddressEditable ? 1 : 0.5)
        .accessibilityIdentifier("serverAddress")
    }

    private var enforcedServersPicker: some View {
        Menu {
            ForEach(configuration.enforcedServers) { server in
                Button(server.name) {
                    selectedServer = server
                    model.enteredServerAddress = server.url.absoluteString
                }
            }
        } label: {
            HStack {
                Group {
                    if let selectedServer {
                        Text(verbatim: selectedServer.name)
                    } else if let enforcedServersPrompt = configuration.enforcedServersPrompt {
                        Text(verbatim: enforcedServersPrompt)
                    } else {
                        Text("Select a server", bundle: .module, comment: "Label of the server picker in the login view before a server was picked.")
                    }
                }
                .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.down")
            }
            .foregroundStyle(foregroundColor)
        }
        .accessibilityIdentifier("enforcedServers")
    }

    private var cancelToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                model.cancel()
                configuration.onCancel?()
            } label: {
                Label {
                    Text("Cancel", bundle: .module, comment: "Button label")
                } icon: {
                    Image(systemName: "xmark")
                }
            }
            .tint(foregroundColor)
            .disabled(model.isAddingAccount)
            .accessibilityIdentifier("cancelLogin")
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
                    Text("Accounts from other Apps", bundle: .module, comment: "Button label")
                } icon: {
                    Image(systemName: "person.badge.plus")
                }
            }
            .tint(foregroundColor)
            .disabled(model.isActive)
            .accessibilityIdentifier("sharedAccounts")
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
        SharedAccount("Jane Doe", user: "jane", on: URL(string: "http://localhost:8080")!, with: Image(systemName: "person.circle.fill"))
    ]

    ServerAddressView(backgroundColor: backgroundColor, brandImage: brandImage, sharedAccounts: sharedAccounts) { _, _, _ in
        print("Add account!")
    }
}

#Preview("Branded") {
    var configuration = LoginFlowConfiguration()
    configuration.foregroundColor = .white
    configuration.serverAddressDescription = "The link to your Example Cloud web interface when you open it in the browser."
    configuration.enforcedServers = [
        LoginFlowConfiguration.Server(name: "Example Cloud", url: URL(string: "https://cloud.example.com")!),
        LoginFlowConfiguration.Server(name: "Example Cloud EU", url: URL(string: "https://eu.cloud.example.com")!)
    ]
    configuration.showsCancelButton = true

    return ServerAddressView(backgroundColor: .constant(.orange), brandImage: Image(systemName: "cloud"), sharedAccounts: [], configuration: configuration) { _, _, _ in
        print("Add account!")
    }
}

#endif
