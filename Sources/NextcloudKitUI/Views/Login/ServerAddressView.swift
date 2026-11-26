// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-FileCopyrightText: 2026 Milen Pivchev
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
        let model = LoginFlowModel(userAgent: userAgent, configuration: configuration, addAccount: addAccount)

        self.sharedAccounts = sharedAccounts.filter { model.isAllowed($0.host) }
        self.configuration = configuration
        self._model = State(initialValue: model)
    }

    // MARK: - Environment

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Bindings

    @Binding var backgroundColor: Color

    // MARK: - State

    ///
    /// The login flow engine. Owns the server address input, polling and web view state.
    ///
    @State private var model: LoginFlowModel

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
        @Bindable var model = model

        return NavigationStack {
            ZStack {
                backgroundColor

                // Scrolls only where the form does not fit, such as on small phones in landscape.
                GeometryReader { proxy in
                    if #available(iOS 26.0, *) {
                        scrollingForm(minHeight: proxy.size.height)
                            .scrollEdgeEffectHidden()
                    } else {
                        scrollingForm(minHeight: proxy.size.height)
                    }
                }
            }
            .ignoresSafeArea()
            .toolbar {
                if configuration.onCancel != nil {
                    cancelToolbarItem
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sharedAccountsSheet(isPresented: $isPresentingSharedAccounts, sharedAccounts: sharedAccounts, selectionHandler: { model.selectSharedAccount($0) })
            // Outside the form, whose disabled state and brand tint would carry over into the sheet, the page and their alerts.
            .codeScannerSheet(model: model)
            .fullScreenCover(item: $model.providerSignUp) {
                model.providerSignUpDidClose()
            } content: { providerSignUp in
                ProviderSignUpView(model: providerSignUp)
            }
            .task(id: model.isPresentingLoginPage) {
                // Clearing the flag cancels this task, which closes the browser sheet.
                guard model.isPresentingLoginPage, let loginAddress = model.loginAddress else { return }

                await model.presentLoginPage(loginAddress, using: webAuthenticationSession)
            }
            .alert(String(localized: "Login Failed", bundle: .module, comment: "Alert title"), isPresented: $model.isPresentingAlert) {
                if model.alertOffersSettings {
                    Button {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            openURL(settingsURL)
                        }
                    } label: {
                        Text("Open Settings", bundle: .module, comment: "Button label in the login error alert which opens the system settings of the app.")
                    }
                }

                Button(role: .cancel) {} label: {
                    Text("OK", bundle: .module, comment: "Button label for error alert dismissal.")
                }
            } message: {
                Text(model.errorMessage ?? "?")
            }
        }
    }

    private func scrollingForm(minHeight: CGFloat) -> some View {
        ScrollView {
            form
                .frame(minHeight: minHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var form: some View {
        VStack {
            Spacer().frame(minHeight: 10, maxHeight: 50)

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
                            Image(systemName: "arrow.right")
                        }
                        .accessibilityLabel(Text("Log in", bundle: .module, comment: "Accessibility label of the button which starts the login."))
                        .accessibilityIdentifier("submitServerAddress")
                    }
                }
                .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(foregroundColor, lineWidth: 1)
                )

                if horizontalSizeClass == .regular {
                    Spacer(minLength: 100)
                }
            }

            Text(verbatim: configuration.serverAddressDescription ?? String(localized: "The address of your Nextcloud web interface when you open it in your browser.", bundle: .module, comment: "Label below the server address field in the login view."))
                .foregroundStyle(foregroundColor)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(4)

            Spacer().frame(height: 30)

            actions

            Spacer()

            if let hostingInformation = configuration.hostingInformation {
                Button(hostingInformation.title) {
                    openURL(hostingInformation.url)
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
                .accessibilityIdentifier("hostYourOwnServer")
            }
        }
        .disabled(model.isActive)
        .tint(foregroundColor)
        // Dark appearance with light text on the background, so the controls match it.
        .environment(\.colorScheme, foregroundColor.readable == .black ? .dark : .light)
        .padding()
        .safeAreaPadding(.all)
    }

    ///
    /// The other ways to log in, below an "or", side by side when the height is compact.
    ///
    @ViewBuilder
    private var actions: some View {
        let isSideBySide = verticalSizeClass == .compact && dynamicTypeSize.isAccessibilitySize == false
        let layout = isSideBySide ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 12))

        VStack(spacing: 37) {
            orSeparator

            layout {
                actionButton(String(localized: "Log in with QR code", bundle: .module, comment: "Button label which opens the QR code scanner in the login view."), systemImage: "qrcode.viewfinder", identifier: "scanQRCode") {
                    model.presentCodeScanner()
                }

                if sharedAccounts.isEmpty == false {
                    actionButton(String(localized: "Accounts from other Apps", bundle: .module, comment: "Button label"), systemImage: "person.badge.plus", identifier: "sharedAccounts") {
                        isPresentingSharedAccounts = true
                    }
                }

                if let providerSignUp = configuration.providerSignUp {
                    actionButton(providerSignUp.title, systemImage: "person.crop.circle.badge.plus", identifier: "signUpWithProvider") {
                        model.presentProviderSignUp(providerSignUp.url)
                    }
                }
            }
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 500 : .infinity)
    }

    private var orSeparator: some View {
        HStack(spacing: 12) {
            Rectangle()
                .frame(height: 1)

            Text("or", bundle: .module, comment: "Separator between the server address field and the other ways to log in.")
                .font(.footnote)

            Rectangle()
                .frame(height: 1)
        }
        .foregroundStyle(foregroundColor.opacity(0.7))
        .accessibilityHidden(true)
    }

    ///
    /// A secondary button tinted with the foreground color, so the server address stays the main way to log in.
    ///
    private func actionButton(_ title: String, systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(verbatim: title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, -3)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier(identifier)
    }

    private var serverAddressField: some View {
        @Bindable var model = model

        return TextField(
            text: $model.enteredServerAddress,
            prompt: Text(verbatim: configuration.serverAddressPrompt ?? "https://example.org/").foregroundColor(foregroundColor.opacity(0.5))
        ) {
            Text("Server Address", bundle: .module, comment: "Label for text field.")
        }
        .textContentType(.URL)
        .autocorrectionDisabled()
        .foregroundStyle(foregroundColor)
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
        .submitLabel(.done)
        .onSubmit {
            model.logIn()
        }
        .disabled(configuration.isServerAddressEditable == false)
        .opacity(configuration.isServerAddressEditable ? 1 : 0.5)
        .padding(.vertical, 5)
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
                Text(verbatim: selectedServer?.name ?? configuration.enforcedServersPrompt ?? String(localized: "Select a server", bundle: .module, comment: "Label of the server picker in the login view before a server was picked."))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.down")
            }
            .foregroundStyle(foregroundColor)
        }
        .padding(.vertical, 5)
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

#Preview("With Links") {
    var configuration = LoginFlowConfiguration()
    configuration.providerSignUp = LoginFlowConfiguration.WebLink(title: "Sign up with provider", url: URL(string: "https://nextcloud.com/signup-ios")!)
    configuration.hostingInformation = LoginFlowConfiguration.WebLink(title: "Host your own server", url: URL(string: "https://nextcloud.com/install")!)

    return ServerAddressView(backgroundColor: .constant(.accentColor), brandImage: Image(systemName: "photo"), sharedAccounts: [], configuration: configuration) { _, _, _ in
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
    configuration.onCancel = {}

    return ServerAddressView(backgroundColor: .constant(.orange), brandImage: Image(systemName: "cloud"), sharedAccounts: [], configuration: configuration) { _, _, _ in
        print("Add account!")
    }
}

#endif
