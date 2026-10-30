// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import XCTest
@testable import NextcloudKit

// XCTest instead of Swift Testing: TestURLProtocol keeps its reply in shared static state,
// so these requests must not run in parallel with other tests using it.
final class ActivityUnitTests: XCTestCase {
    private let account = "activity-unit-test-\(UUID().uuidString)"

    // Snowflake IDs need more than the 53 bits a JavaScript number can hold exactly
    private let snowflakeId = 130_000_000_000_000_123

    override func tearDown() {
        TestURLProtocol.reset()
        super.tearDown()
    }

    func test_getActivity_readsActivityIdsSentAsNumberOrString() async {
        let json = """
        {"ocs": {"meta": {"status": "ok", "statuscode": 200, "message": "OK"}, "data": [
            {"activity_id": \(snowflakeId), "app": "files"},
            {"activity_id": "\(snowflakeId + 1)", "app": "files"},
            {"activity_id": "42", "app": "files"}
        ]}}
        """
        TestURLProtocol.setReply(status: 200, data: Data(json.utf8), headers: [
            "X-Activity-First-Known": String(snowflakeId + 1),
            "X-Activity-Last-Given": String(snowflakeId)
        ])

        let result = await makeKit().getActivityAsync(since: 0,
                                                      limit: 50,
                                                      objectId: nil,
                                                      objectType: nil,
                                                      previews: false,
                                                      account: account)

        XCTAssertEqual(result.error.errorCode, NKError.success.errorCode)
        XCTAssertEqual(result.activities.map(\.idActivity), [snowflakeId, snowflakeId + 1, 42])
        XCTAssertEqual(result.activityFirstKnown, snowflakeId + 1)
        XCTAssertEqual(result.activityLastGiven, snowflakeId)
    }

    func test_getActivity_withInvalidActivityId_returnsZero() async {
        let json = """
        {"ocs": {"meta": {"status": "ok", "statuscode": 200, "message": "OK"}, "data": [
            {"activity_id": "abc", "app": "files"}
        ]}}
        """
        TestURLProtocol.setReply(status: 200, data: Data(json.utf8))

        let result = await makeKit().getActivityAsync(since: 0,
                                                      limit: 50,
                                                      objectId: nil,
                                                      objectType: nil,
                                                      previews: false,
                                                      account: account)

        XCTAssertEqual(result.activities.map(\.idActivity), [0])
    }

    private func makeKit() -> NextcloudKit {
        let kit = NextcloudKit()
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [TestURLProtocol.self]
        let session = NKSession(nkCommonInstance: kit.nkCommonInstance,
                                urlBase: "https://example.invalid",
                                user: "user",
                                userId: "user",
                                password: "password",
                                account: account,
                                userAgent: "NextcloudKit unit test",
                                groupIdentifier: "",
                                httpMaximumConnectionsPerHost: 6,
                                httpMaximumConnectionsPerHostInDownload: 6,
                                httpMaximumConnectionsPerHostInUpload: 6,
                                sessionDataOverride: Session(configuration: configuration))
        kit.nkCommonInstance.nksessions.append(session)
        return kit
    }
}
