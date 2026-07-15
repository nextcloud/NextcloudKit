// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import NextcloudKit

// The per-account `sessionData` config can't be injected with a mock URLProtocol, so these tests
// validate the Codable models and the OCS envelope shape the governance endpoints decode, plus the
// enum raw values that build the request paths.
final class GovernanceUnitTests: XCTestCase {
    private struct OCSEnvelope<T: Decodable>: Decodable {
        let ocs: Inner
        struct Inner: Decodable { let data: T }
    }

    private struct GenericResponse: Decodable { let message: String }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func test_decodeAvailableLabels_withValidData_shouldParseFieldsAndDropUnknownScopes() throws {
        let data = try fixture("GovernanceAvailableLabelsMock")
        let labels = try JSONDecoder().decode(OCSEnvelope<[NKGovernanceLabel]>.self, from: data).ocs.data

        XCTAssertEqual(labels.count, 2)

        let first = labels[0]
        XCTAssertEqual(first.id, "1")
        XCTAssertEqual(first.name, "Public")
        XCTAssertEqual(first.priority, 0)
        XCTAssertEqual(first.description, "Public label")
        XCTAssertEqual(first.color, "#00FF00")
        XCTAssertEqual(first.scopes, [.files, .mails])

        // The unknown "FUTURE_SCOPE" value is dropped rather than failing the whole decode.
        XCTAssertEqual(labels[1].scopes, [.files])
    }

    func test_decodeEntityLabels_withSensitivityAndRetention_shouldParseBoth() throws {
        let data = try fixture("GovernanceEntityLabelsMock")
        let entity = try JSONDecoder().decode(OCSEnvelope<NKGovernanceEntityLabels>.self, from: data).ocs.data

        XCTAssertEqual(entity.sensitivity?.id, "2")
        XCTAssertEqual(entity.sensitivity?.name, "Restricted")
        XCTAssertEqual(entity.retention.count, 1)
        XCTAssertEqual(entity.retention.first?.id, "5")
        XCTAssertEqual(entity.hold.map(\.id), ["9"])
    }

    func test_decodeEntityLabels_withNullSensitivityAndEmptyRetention_shouldDefaultGracefully() throws {
        let data = try fixture("GovernanceEntityLabelsEmptyMock")
        let entity = try JSONDecoder().decode(OCSEnvelope<NKGovernanceEntityLabels>.self, from: data).ocs.data

        XCTAssertNil(entity.sensitivity)
        XCTAssertTrue(entity.retention.isEmpty)
        XCTAssertTrue(entity.hold.isEmpty)
    }

    func test_decodeGenericResponse_shouldParseMessage() throws {
        let data = try fixture("GovernanceGenericResponseMock")
        let response = try JSONDecoder().decode(OCSEnvelope<GenericResponse>.self, from: data).ocs.data

        XCTAssertEqual(response.message, "Label applied")
    }

    func test_decodeAvailableAllLabels_shouldGroupByType() throws {
        let data = try fixture("GovernanceAvailableAllLabelsMock")
        let available = try JSONDecoder().decode(OCSEnvelope<NKGovernanceAvailableLabels>.self, from: data).ocs.data

        XCTAssertEqual(available.sensitivity.map(\.id), ["1"])
        XCTAssertEqual(available.retention.map(\.id), ["5"])
        XCTAssertEqual(available.hold.map(\.id), ["9"])
        XCTAssertEqual(available.sensitivity.first?.scopes, [.files, .mails])
    }

    func test_labelType_rawValues_shouldMatchApiPathSegments() {
        XCTAssertEqual(NKGovernanceLabelType.sensitivity.rawValue, "SENSITIVITY")
        XCTAssertEqual(NKGovernanceLabelType.retention.rawValue, "RETENTION")
        XCTAssertEqual(NKGovernanceLabelType.hold.rawValue, "HOLD")
    }

    func test_labelScope_rawValues_shouldMatchApiValues() {
        XCTAssertEqual(NKGovernanceLabelScope(rawValue: "FILES"), .files)
        XCTAssertEqual(NKGovernanceLabelScope(rawValue: "MAILS"), .mails)
        XCTAssertNil(NKGovernanceLabelScope(rawValue: "FUTURE_SCOPE"))
    }
}
