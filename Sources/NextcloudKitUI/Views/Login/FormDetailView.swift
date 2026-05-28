// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Present a text in style of key-value text line in a SwiftUI form.
///
public struct FormDetailView: View {
    let onTapGesture: (() -> Void)?
    let title: LocalizedStringKey

    @Binding var detail: String

    ///
    /// - Parameters:
    ///     - title: Shown at the leading end as the label for the detail presented.
    ///     - detail: Shown at the trailing end as the detail for the label presented.
    ///     - onTapGesture: An optional tap handler.
    ///
    public init(_ title: LocalizedStringKey, detail: Binding<String>, onTapGesture: (() -> Void)? = nil) {
        self.title = title
        self._detail = detail
        self.onTapGesture = onTapGesture
    }

    public var body: some View {
        HStack {
            Text(title)

            if detail.isEmpty == false {
                Spacer()

                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle()) // Required to make the whole HStack tappable.
        .onTapGesture {
            if let onTapGesture {
                onTapGesture()
            }
        }
    }
}

#Preview {
    Form {
        Section("Without Detail") {
            FormDetailView("Title", detail: .constant(""))
        }

        Section("With Detail") {
            FormDetailView("Title", detail: .constant("Detail"))
        }

        Section("Tappable") {
            FormDetailView("Title", detail: .constant("Tap Me")) {
                print("FormDetailView was tapped!")
            }
        }
    }
}
