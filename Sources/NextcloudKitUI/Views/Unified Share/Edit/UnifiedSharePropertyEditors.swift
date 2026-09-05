// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

/// Renders the right editor for a property's concrete type, with a hint/error caption.
struct PropertyRow: View {
    let property: NKUnifiedShareProperty
    let error: String?
    let onCommit: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            editor

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(error != nil ? Color.red : Color.secondary)
            }
        }
    }

    private var caption: String? {
        if let error, !error.isEmpty {
            return error
        }

        if let hint = property.hint, !hint.isEmpty {
            return hint
        }

        return nil
    }

    @ViewBuilder
    private var editor: some View {
        switch property {
        case let property as NKUnifiedSharePropertyBoolean:
            BooleanPropertyEditor(property: property, onCommit: onCommit)
        case let property as NKUnifiedSharePropertyEnum:
            EnumPropertyEditor(property: property, onCommit: onCommit)
        case let property as NKUnifiedSharePropertyDate:
            DatePropertyEditor(property: property, onCommit: onCommit)
        case let property as NKUnifiedSharePropertyPassword:
            TextPropertyEditor(property: property, secure: true, onCommit: onCommit)
        case let property as NKUnifiedSharePropertyString:
            TextPropertyEditor(property: property, secure: false, onCommit: onCommit)
        default:
            LabeledContent(property.displayName) {
                Text(property.value ?? "").foregroundStyle(.secondary)
            }
        }
    }
}

private struct BooleanPropertyEditor: View {
    let property: NKUnifiedSharePropertyBoolean
    let onCommit: (String?) -> Void
    @State private var isOn: Bool

    init(property: NKUnifiedSharePropertyBoolean, onCommit: @escaping (String?) -> Void) {
        self.property = property
        self.onCommit = onCommit
        _isOn = State(initialValue: property.value == "true")
    }

    var body: some View {
        Toggle(property.displayName, isOn: $isOn)
            .onChange(of: isOn) {
                onCommit(isOn ? "true" : "false")
            }
    }
}

private struct EnumPropertyEditor: View {
    let property: NKUnifiedSharePropertyEnum
    let onCommit: (String?) -> Void
    @State private var selection: String?

    init(property: NKUnifiedSharePropertyEnum, onCommit: @escaping (String?) -> Void) {
        self.property = property
        self.onCommit = onCommit

        let value = property.value
        _selection = State(initialValue: (value?.isEmpty ?? true) ? nil : value)
    }

    var body: some View {
        Picker(property.displayName, selection: $selection) {
            ForEach(property.validValues, id: \.self) { value in
                Text(value).tag(String?.some(value))
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selection) {
            if let selection {
                onCommit(selection)
            }
        }
    }
}

private struct DatePropertyEditor: View {
    let property: NKUnifiedSharePropertyDate
    let onCommit: (String?) -> Void
    @State private var date: Date
    @State private var hasDate: Bool
    @State private var showsPicker = false

    init(property: NKUnifiedSharePropertyDate, onCommit: @escaping (String?) -> Void) {
        self.property = property
        self.onCommit = onCommit
        let parsed = Self.parse(property.value)
        _date = State(initialValue: parsed ?? Date())
        _hasDate = State(initialValue: parsed != nil)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(property.displayName)
                .foregroundStyle(.primary)

            Spacer()

            if hasDate {
                Text(date, format: Date.FormatStyle(date: .abbreviated))
                    .foregroundStyle(.secondary)

                Button {
                    hasDate = false

                    if let value = property.value, !value.isEmpty {
                        onCommit(nil)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            } else {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showsPicker = true
        }
        .popover(isPresented: $showsPicker) {
            DatePicker(
                "",
                selection: Binding(
                    get: { date },
                    set: { picked in
                        date = picked
                        hasDate = true
                        onCommit(Self.format(picked))
                    }
                ),
                in: dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(width: 320)
            .padding(8)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var dateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let lower = max(Self.parse(property.minDate) ?? today, today)
        let upper = Self.parse(property.maxDate) ?? .distantFuture

        return lower...max(lower, upper)
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = .current
        return formatter
    }()

    static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else {
            return nil
        }

        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    static func format(_ date: Date) -> String {
        formatter.string(from: Calendar.current.startOfDay(for: date))
    }
}

private struct TextPropertyEditor: View {
    private static let labelPropertyClass = "OC\\Core\\Sharing\\Property\\LabelSharePropertyType"

    let property: NKUnifiedShareProperty
    let secure: Bool
    let onCommit: (String?) -> Void
    @State private var isPresented = false
    @State private var draft: String
    @State private var committed: String
    @State private var isPasswordVisible = false

    init(property: NKUnifiedShareProperty, secure: Bool, onCommit: @escaping (String?) -> Void) {
        self.property = property
        self.secure = secure
        self.onCommit = onCommit
        let initial = property.value ?? ""
        _draft = State(initialValue: initial)
        _committed = State(initialValue: initial)
    }

    var body: some View {
        HStack {
            Button {
                draft = committed
                isPresented = true
            } label: {
                Text(displayValue)
                    .foregroundStyle(committed.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if secure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? String(localized: "Hide password") : String(localized: "Show password"))
            }
        }
        .alert(property.displayName, isPresented: $isPresented) {
            if secure {
                SecureField(placeholder, text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $draft)
            }

            Button(String(localized: "Cancel"), role: .cancel) {
                draft = committed
            }

            Button(String(localized: "Save")) {
                guard draft != committed else {
                    return
                }

                committed = draft
                onCommit(draft.isEmpty ? nil : draft)
            }
        }
    }

    private var placeholder: String {
        property.class == Self.labelPropertyClass ? String(localized: "Add a label") : property.displayName
    }

    private var displayValue: String {
        guard !committed.isEmpty else {
            return placeholder
        }

        return secure && !isPasswordVisible ? String(repeating: "•", count: min(committed.count, 12)) : committed
    }
}
