// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import NextcloudKit

/// Behavior:
/// - For Nextcloud 32 and newer, WCF enforcement depends on the `windowsCompatibleFilenamesEnabled` flag
///  provided by the server capabilities.
/// - For Nextcloud 30 and 31, WCF restrictions are always applied (feature considered enabled).
/// - For versions older than 30, WCF is not supported, and no restrictions are applied.
@Suite("WCF restriction checks")
struct CheckWCFRestrictionsTests {
    private func makeCapabilities(serverMajor: Int, wcfEnabled: Bool) -> NKCapabilities.Capabilities {
        let capabilities = NKCapabilities.Capabilities()
        capabilities.serverVersionMajor = serverMajor
        capabilities.windowsCompatibleFilenamesEnabled = wcfEnabled
        return capabilities
    }

    @Test("Returns false for versions older than 30")
    func returnsFalseForVersionsOlderThan30() {
        let capabilities = makeCapabilities(serverMajor: 29, wcfEnabled: true)
        #expect(capabilities.shouldEnforceWindowsCompatibleFilenames == false)
    }

    @Test("Returns true for version 30 when WCF is ALWAYS enabled. Flag is ignored.")
    func returnsTrueForVersion30() {
        let capabilities = makeCapabilities(serverMajor: 30, wcfEnabled: false)
        #expect(capabilities.shouldEnforceWindowsCompatibleFilenames == true)
    }

    @Test("Returns true for version 31 when WCF is ALAWYS enabled. Flag is ignored.")
    func returnsTrueForVersion31() {
        let capabilities = makeCapabilities(serverMajor: 31, wcfEnabled: false)
        #expect(capabilities.shouldEnforceWindowsCompatibleFilenames == true)
    }

    @Test("Returns true for version 32 when WCF enabled")
    func returnsTrueForVersion32WhenEnabled() {
        let capabilities = makeCapabilities(serverMajor: 32, wcfEnabled: true)
        #expect(capabilities.shouldEnforceWindowsCompatibleFilenames == true)
    }

    @Test("Returns false for version 32 when WCF disabled")
    func returnsFalseForVersion32WhenDisabled() {
        let capabilities = makeCapabilities(serverMajor: 32, wcfEnabled: false)
        #expect(capabilities.shouldEnforceWindowsCompatibleFilenames == false)
    }
}
