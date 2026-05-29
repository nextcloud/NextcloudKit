// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Property type discriminator.
public enum NKUnifiedSharePropertyType: String, Codable, Sendable {
    case date
    case enumeration = "enum"
    case boolean
    case password
    case string
}

/// Base class for a unified share property.
///
/// Variant fields live on the concrete subclasses (`NKUnifiedSharePropertyDate`, …). When decoding
/// `NKUnifiedShare.properties`, the dispatch on `type` picks the right subclass.
public class NKUnifiedShareProperty: Codable {
    public let `class`: String
    public let displayName: String
    public let hint: String?
    public let priority: Int
    public let required: Bool
    public let value: String?
    public let type: NKUnifiedSharePropertyType

    enum CodingKeys: String, CodingKey {
        case `class`
        case displayName = "display_name"
        case hint
        case priority
        case required
        case value
        case type
    }

    public init(class: String, displayName: String, hint: String?, priority: Int, required: Bool, value: String?, type: NKUnifiedSharePropertyType) {
        self.class = `class`
        self.displayName = displayName
        self.hint = hint
        self.priority = priority
        self.required = required
        self.value = value
        self.type = type
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.class = try c.decode(String.self, forKey: .class)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.hint = try c.decodeIfPresent(String.self, forKey: .hint)
        self.priority = try c.decode(Int.self, forKey: .priority)
        self.required = try c.decode(Bool.self, forKey: .required)
        self.value = try c.decodeIfPresent(String.self, forKey: .value)
        self.type = try c.decode(NKUnifiedSharePropertyType.self, forKey: .type)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(self.class, forKey: .class)
        try c.encode(displayName, forKey: .displayName)
        try c.encodeIfPresent(hint, forKey: .hint)
        try c.encode(priority, forKey: .priority)
        try c.encode(required, forKey: .required)
        try c.encodeIfPresent(value, forKey: .value)
        try c.encode(type, forKey: .type)
    }
}

/// Date-typed property; adds an optional valid range.
public final class NKUnifiedSharePropertyDate: NKUnifiedShareProperty {
    public let minDate: String?
    public let maxDate: String?

    enum DateKeys: String, CodingKey {
        case minDate = "min_date"
        case maxDate = "max_date"
    }

    public init(class: String, displayName: String, hint: String? = nil, priority: Int, required: Bool, value: String? = nil, minDate: String? = nil, maxDate: String? = nil) {
        self.minDate = minDate
        self.maxDate = maxDate
        super.init(class: `class`, displayName: displayName, hint: hint, priority: priority, required: required, value: value, type: .date)
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DateKeys.self)
        self.minDate = try c.decodeIfPresent(String.self, forKey: .minDate)
        self.maxDate = try c.decodeIfPresent(String.self, forKey: .maxDate)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var c = encoder.container(keyedBy: DateKeys.self)
        try c.encodeIfPresent(minDate, forKey: .minDate)
        try c.encodeIfPresent(maxDate, forKey: .maxDate)
    }
}

/// Enum-typed property; carries the allowed value set.
public final class NKUnifiedSharePropertyEnum: NKUnifiedShareProperty {
    public let validValues: [String]

    enum EnumKeys: String, CodingKey {
        case validValues = "valid_values"
    }

    public init(class: String, displayName: String, hint: String? = nil, priority: Int, required: Bool, value: String? = nil, validValues: [String]) {
        self.validValues = validValues
        super.init(class: `class`, displayName: displayName, hint: hint, priority: priority, required: required, value: value, type: .enumeration)
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: EnumKeys.self)
        self.validValues = try c.decode([String].self, forKey: .validValues)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var c = encoder.container(keyedBy: EnumKeys.self)
        try c.encode(validValues, forKey: .validValues)
    }
}

/// Boolean-typed property; no additional fields.
public final class NKUnifiedSharePropertyBoolean: NKUnifiedShareProperty {
    public init(class: String, displayName: String, hint: String? = nil, priority: Int, required: Bool, value: String? = nil) {
        super.init(class: `class`, displayName: displayName, hint: hint, priority: priority, required: required, value: value, type: .boolean)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}

/// Password-typed property; no additional fields.
public final class NKUnifiedSharePropertyPassword: NKUnifiedShareProperty {
    public init(class: String, displayName: String, hint: String? = nil, priority: Int, required: Bool, value: String? = nil) {
        super.init(class: `class`, displayName: displayName, hint: hint, priority: priority, required: required, value: value, type: .password)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}

/// String-typed property; adds optional length bounds.
public final class NKUnifiedSharePropertyString: NKUnifiedShareProperty {
    public let minLength: Int?
    public let maxLength: Int?

    enum StringKeys: String, CodingKey {
        case minLength = "min_length"
        case maxLength = "max_length"
    }

    public init(class: String, displayName: String, hint: String? = nil, priority: Int, required: Bool, value: String? = nil, minLength: Int? = nil, maxLength: Int? = nil) {
        self.minLength = minLength
        self.maxLength = maxLength
        super.init(class: `class`, displayName: displayName, hint: hint, priority: priority, required: required, value: value, type: .string)
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: StringKeys.self)
        self.minLength = try c.decodeIfPresent(Int.self, forKey: .minLength)
        self.maxLength = try c.decodeIfPresent(Int.self, forKey: .maxLength)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var c = encoder.container(keyedBy: StringKeys.self)
        try c.encodeIfPresent(minLength, forKey: .minLength)
        try c.encodeIfPresent(maxLength, forKey: .maxLength)
    }
}
