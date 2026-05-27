// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Account menu to be used in the toolbar.
///
public struct AccountButtonView: View {
    var accounts: [Account]
    let supportsMultipleAccounts: Bool

    @Binding var activeAccount: Account?
    @Binding var showLogin: Bool
    @Binding var showSettings: Bool

    @State var showPopover: Bool = false

    ///
    /// Set up a new account button view.
    ///
    /// - Parameters:
    ///     - activeAccount: The currently selected account.
    ///     - accounts: All accounts available for selection.
    ///     - showLogin: Whether the app should present a login view or not.
    ///     - showSettings: Whether the app should present a settings view or not.
    ///     - supportsMultipleAccounts: Whether the button should adapt for a multi-account presentation. This means the offering to add another account and showing a heading above the account list which otherwise contains a single item.
    ///     - showPopover: Whether the popover is presented by default or not.
    ///
    public init(activeAccount: Binding<Account?>, accounts: [Account], showLogin: Binding<Bool>, showSettings: Binding<Bool>, supportsMultipleAccounts: Bool = true, showPopover: Bool = false) {
        self._activeAccount = activeAccount
        self.accounts = accounts
        self._showLogin = showLogin
        self._showSettings = showSettings
        self.showPopover = showPopover
        self.supportsMultipleAccounts = supportsMultipleAccounts
    }

    public var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            if let activeAccount {
                activeAccount.image
            } else {
                Image(systemName: "questionmark.circle.dashed")
            }
        }
        .popover(isPresented: $showPopover) {
            VStack {
                if supportsMultipleAccounts {
                    Text("Accounts")
                        .bold()
                        .padding(.top)

                    Divider()
                } else {
                    Spacer(minLength: 10)
                }

                ForEach(accounts) { account in
                    Button {
                        selectAccount(account)
                    } label: {
                        HStack(spacing: 0) {
                            // Active account indicator
                            Image(systemName: "circle.fill")
                                .resizable()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(activeAccount == account ? Color.accentColor : Color.clear)
                                .padding([.leading, .trailing], 10)

                            // Account image
                            account.image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .padding(.trailing, 10)

                            // Account details
                            VStack(alignment: .leading) {
                                Text(verbatim: account.name)
                                    .foregroundStyle(.primary)

                                Text(verbatim: account.host.absoluteString)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.trailing)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    Divider()
                }

                HStack {
                    // Add account button
                    if supportsMultipleAccounts {
                        Button {
                            showLogin = true
                        } label: {
                            Image(systemName: "person.fill.badge.plus")
                                .padding(.top, 5)
                                .padding([.leading, .bottom, .trailing])
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Settings button
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .padding(.top, 5)
                            .padding([.leading, .bottom, .trailing])
                    }
                    .buttonStyle(.plain)
                }
            }
            .presentationCompactAdaptation(.popover)
        }
    }

    func selectAccount(_ account: Account) {
        activeAccount = account
        showPopover = false
    }
}

#if DEBUG

#Preview("Closed") {
    @Previewable @State var selectedAccount: Account? = PreviewData.account
    @Previewable @State var showLogin = false
    @Previewable @State var showSettings = false

    NavigationStack {
        Text("Closed Account Popover")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                AccountButtonView(activeAccount: $selectedAccount, accounts: [PreviewData.account], showLogin: $showLogin, showSettings: $showSettings, showPopover: false)
            }
        }
    }
}

#Preview("Single Account") {
    @Previewable @State var selectedAccount: Account? = PreviewData.account
    @Previewable @State var showLogin = false
    @Previewable @State var showSettings = false

    NavigationStack {
        Text("Single Account")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                AccountButtonView(activeAccount: $selectedAccount, accounts: [PreviewData.account], showLogin: $showLogin, showSettings: $showSettings, supportsMultipleAccounts: false, showPopover: true)
            }
        }
    }
}

#Preview("Multiple Accounts") {
    @Previewable @State var selectedAccount: Account? = PreviewData.account
    @Previewable @State var showLogin = false
    @Previewable @State var showSettings = false

    NavigationStack {
        Text("Multiple Accounts")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                AccountButtonView(activeAccount: $selectedAccount, accounts: PreviewData.accounts, showLogin: $showLogin, showSettings: $showSettings, showPopover: true)
            }
        }
    }
}

#endif
