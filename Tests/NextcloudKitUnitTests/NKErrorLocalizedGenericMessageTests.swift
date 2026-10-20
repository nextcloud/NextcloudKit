// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Foundation
import Testing
@testable import NextcloudKit

/// Tests for the message ``NKError/localizedGenericMessage`` shows to users.
struct NKErrorLocalizedGenericMessageTests {
    @Test(arguments: NKError.Kind.allCases)
    func kindMessage(kind: NKError.Kind) {
        let message = NKError(errorCode: -1, errorDescription: "Technical description", kind: kind).localizedGenericMessage

        #expect(!message.isEmpty)
        #expect(message != "Technical description")
    }

    @Test func distinctMessagePerKind() {
        let messages = Set(NKError.Kind.allCases.map { NKError(errorCode: -1, kind: $0).localizedGenericMessage })

        #expect(messages.count == NKError.Kind.allCases.count)
    }

    @Test func prefersUserFriendlyServerMessage() throws {
        let url = try #require(URL(string: "https://cloud.example.com/ocs/v2.php/apps/files_sharing/api/v1/shares"))
        let body = Data(#"{"ocs":{"meta":{"statuscode":400,"message":"Password needs to be at least 10 characters long"},"data":[]}}"#.utf8)
        let response = HTTPURLResponse(url: url, statusCode: 400, httpVersion: "HTTP/1.1", headerFields: nil)
        let dataResponse = AFDataResponse<Data>(request: URLRequest(url: url), response: response, data: body, metrics: nil, serializationDuration: 0, result: .failure(.responseValidationFailed(reason: .unacceptableStatusCode(code: 400))))

        #expect(NKError(error: dataResponse.error, afResponse: dataResponse).localizedGenericMessage == "Password needs to be at least 10 characters long")
    }
}
