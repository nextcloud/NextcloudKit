// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// The alert for errors of ``LoginFlowModel``, shown by the login view.
///
struct LoginFlowAlert: ViewModifier {
    @Environment(\.openURL) private var openURL

    let model: LoginFlowModel
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.alert(String(localized: "Login Failed", bundle: .module, comment: "Alert title"), isPresented: $isPresented) {
            if model.alertAction == .openSettings {
                Button {
                    model.dismissAlert()

                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                } label: {
                    Text("Open Settings", bundle: .module, comment: "Button label in the login error alert which opens the system settings of the app.")
                }
            }

            Button(role: .cancel) {
                model.dismissAlert()
            } label: {
                Text("OK", bundle: .module, comment: "Button label for error alert dismissal.")
            }
        } message: {
            Text(model.errorMessage ?? "?")
        }
    }
}

extension View {
    func loginFlowAlert(model: LoginFlowModel, isPresented: Binding<Bool>) -> some View {
        modifier(LoginFlowAlert(model: model, isPresented: isPresented))
    }
}
