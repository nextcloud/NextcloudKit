// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import NextcloudKit

///
/// Tests for the message ``NKError/localizedGenericMessage`` shows to users.
///
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

    @Test func prefersUserFacingServerMessage() {
        let body = Data(#"{"ocs":{"meta":{"statuscode":400},"data":"Password needs to be at least 10 characters long"}}"#.utf8)
        let error = NKError(errorCode: 400, errorDescription: "400: Bad request", responseData: body)

        #expect(error.localizedGenericMessage == "Password needs to be at least 10 characters long")
    }

    @Test func ignoresTechnicalServerMessage() {
        let body = Data(#"<?xml version="1.0"?><d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns"><s:exception>Sabre\DAV\Exception\Conflict</s:exception><s:message>Parent node does not exist</s:message></d:error>"#.utf8)
        let error = NKError(errorCode: 409, errorDescription: "Parent node does not exist", responseData: body)

        #expect(error.localizedGenericMessage != "Parent node does not exist")
        #expect(error.localizedGenericMessage == NKError(errorCode: 409).localizedGenericMessage)
    }
}
