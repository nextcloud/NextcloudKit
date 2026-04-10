// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftyXMLParser

public struct NKTag: Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let color: String?

    public init(id: String, name: String, color: String?) {
        self.id = id
        self.name = name
        self.color = color
    }

    static func parse(xmlData: Data) -> [NKTag] {
        let xml = XML.parse(xmlData)
        let responses = xml["d:multistatus", "d:response"]
        var tags: [NKTag] = []

        for response in responses {
            let propstat = response["d:propstat"][0]
            guard let id = propstat["d:prop", "oc:id"].text,
                  let name = propstat["d:prop", "oc:display-name"].text else {
                continue
            }

            let color = normalizedColor(propstat["d:prop", "nc:color"].text)

            tags.append(NKTag(id: id, name: name, color: color))
        }

        return tags
    }

    static func parse(systemTagElements: XML.Accessor) -> [NKTag] {
        var tags: [NKTag] = []

        for element in systemTagElements {
            guard let name = element.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                continue
            }

            let id = element.attributes["oc:id"] ?? ""
            let color = normalizedColor(element.attributes["nc:color"])
            tags.append(NKTag(id: id, name: name, color: color))
        }

        return tags
    }

    private static func normalizedColor(_ rawValue: String?) -> String? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }
        return rawValue.hasPrefix("#") ? rawValue : "#\(rawValue)"
    }
}
