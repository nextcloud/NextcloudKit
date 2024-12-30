// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftyXMLParser

public class NKRecommendation {
    public var id: String
    public var timestamp: Date?
    public var name: String
    public var directory: String
    public var extensionType: String
    public var mimeType: String
    public var hasPreview: Bool
    public var reason: String

    init(id: String, timestamp: Date?, name: String, directory: String, extensionType: String, mimeType: String, hasPreview: Bool, reason: String) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.directory = directory
        self.extensionType = extensionType
        self.mimeType = mimeType
        self.hasPreview = hasPreview
        self.reason = reason
    }
}

class XMLToRecommendationParser {
    func parse(xml: String) -> [NKRecommendation]? {
        guard let data = xml.data(using: .utf8) else { return nil }
        let xml = XML.parse(data)

        // Parsing "enabled"
        guard let enabledString = xml["ocs", "data", "enabled"].text,
              Bool(enabledString == "1")
        else {
            return nil
        }

        // Parsing "recommendations"
        var recommendations: [NKRecommendation] = []
        let elements = xml["ocs", "data", "recommendations", "element"]

        for element in elements {
            let id = element["id"].text ?? ""
            var timestamp: Date?
            if let timestampDouble = element["timestamp"].double, timestampDouble > 0 {
                timestamp = Date(timeIntervalSince1970: timestampDouble)
            }
            let name = element["name"].text ?? ""
            let directory = element["directory"].text ?? ""
            let extensionType = element["extension"].text ?? ""
            let mimeType = element["mimeType"].text ?? ""
            let hasPreview = element["hasPreview"].text == "1"
            let reason = element["reason"].text ?? ""

            let recommendation = NKRecommendation(
                id: id,
                timestamp: timestamp,
                name: name,
                directory: directory,
                extensionType: extensionType,
                mimeType: mimeType,
                hasPreview: hasPreview,
                reason: reason
            )
            recommendations.append(recommendation)
        }

        return recommendations
    }
}
