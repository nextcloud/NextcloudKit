// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import NextcloudKit

final class GovernanceUnitTests: XCTestCase {
    private struct OCSEnvelope<T: Decodable>: Decodable {
        let ocs: Inner

        struct Inner: Decodable {
            let data: T
        }
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func test_decodeAvailableLabels_shouldGroupByTypeAndMarkAssigned() throws {
        let data = try fixture("GovernanceAvailableAllLabelsMock")
        let available = try JSONDecoder().decode(OCSEnvelope<NKGovernanceAvailableLabels>.self, from: data).ocs.data

        XCTAssertEqual(available.sensitivity.map(\.name), ["Public", "Confidential"])
        XCTAssertEqual(available.retention.count, 2)
        XCTAssertTrue(available.hold.isEmpty)

        XCTAssertEqual(available.sensitivity.filter(\.isAssigned).map(\.name), ["Confidential"])
        XCTAssertEqual(available.retention.filter(\.isAssigned).map(\.name), ["Employee Records (HR)"])

        XCTAssertEqual(available.sensitivity.first?.color, "#2E7D32")
        XCTAssertEqual(available.sensitivity.first?.priority, 0)
    }

    func test_decodeLabel_withNullOrMissingOptionalFields_shouldStillDecode() throws {
        let json = Data("""
        [
            {"id": "1", "name": "Minimal"},
            {"id": "2", "name": "Nulls", "priority": null, "description": null, "color": null, "isAssigned": null}
        ]
        """.utf8)
        let labels = try JSONDecoder().decode([NKGovernanceLabel].self, from: json)

        XCTAssertEqual(labels.count, 2)
        XCTAssertEqual(labels[0].priority, 0)
        XCTAssertEqual(labels[0].description, "")
        XCTAssertEqual(labels[0].color, "")
        XCTAssertFalse(labels[1].isAssigned)
    }

    func test_decodeLabel_withColorMissingHashPrefix_shouldNormalize() throws {
        let json = Data("""
        [
            {"id": "1", "name": "A", "color": "FF0000"},
            {"id": "2", "name": "B", "color": "#00FF00"}
        ]
        """.utf8)
        let labels = try JSONDecoder().decode([NKGovernanceLabel].self, from: json)

        XCTAssertEqual(labels[0].color, "#FF0000")
        XCTAssertEqual(labels[1].color, "#00FF00")
    }
}
