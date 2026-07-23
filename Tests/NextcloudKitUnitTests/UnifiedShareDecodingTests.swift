// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import NextcloudKit

/// Verifies that `NKUnifiedShare` decodes through `NKOCSWrapper<T>` and that the polymorphic
/// `properties` array yields the right concrete `NKUnifiedShareProperty` subclass per element.
@Suite("Unified share Codable")
struct UnifiedShareDecodingTests {
    private func decodeShare(json: String) throws -> NKUnifiedShare {
        let data = Data(json.utf8)
        let wrap = try JSONDecoder().decode(NKOCSWrapper<NKUnifiedShare>.self, from: data)
        return wrap.ocs.data
    }

    @Test("Decodes all five property variants into the matching subclass")
    func decodesAllPropertyVariants() throws {
        let json = """
        {
          "ocs": {
            "meta": { "status": "ok", "statuscode": 200 },
            "data": {
              "id": "s1",
              "owner": {
                "user_id": "alice",
                "instance": null,
                "display_name": "Alice",
                "icon": { "svg": "<svg/>" }
              },
              "last_updated": 1730000000000,
              "state": "active",
              "sources": [],
              "recipients": [],
              "permissions": [],
              "properties": [
                {
                  "class": "expiration",
                  "display_name": "Expiration",
                  "hint": null,
                  "priority": 10,
                  "required": false,
                  "value": null,
                  "type": "date",
                  "min_date": "2026-01-01",
                  "max_date": null
                },
                {
                  "class": "role",
                  "display_name": "Role",
                  "hint": null,
                  "priority": 20,
                  "required": true,
                  "value": "editor",
                  "type": "enum",
                  "valid_values": ["viewer", "editor"]
                },
                {
                  "class": "download",
                  "display_name": "Allow download",
                  "hint": null,
                  "priority": 30,
                  "required": false,
                  "value": "true",
                  "type": "boolean"
                },
                {
                  "class": "password",
                  "display_name": "Password",
                  "hint": "Min 8 chars",
                  "priority": 40,
                  "required": false,
                  "value": null,
                  "type": "password"
                },
                {
                  "class": "note",
                  "display_name": "Note",
                  "hint": null,
                  "priority": 50,
                  "required": false,
                  "value": "hi",
                  "type": "string",
                  "min_length": 0,
                  "max_length": 1000
                }
              ]
            }
          }
        }
        """

        let share = try decodeShare(json: json)

        #expect(share.id == "s1")
        #expect(share.state == .active)
        #expect(share.lastUpdated == 1_730_000_000_000)
        #expect(share.properties.count == 5)

        let p0 = try #require(share.properties[0] as? NKUnifiedSharePropertyDate)
        #expect(p0.type == .date)
        #expect(p0.minDate == "2026-01-01")
        #expect(p0.maxDate == nil)

        let p1 = try #require(share.properties[1] as? NKUnifiedSharePropertyEnum)
        #expect(p1.type == .enumeration)
        #expect(p1.validValues == ["viewer", "editor"])

        let p2 = try #require(share.properties[2] as? NKUnifiedSharePropertyBoolean)
        #expect(p2.type == .boolean)
        #expect(p2.value == "true")

        let p3 = try #require(share.properties[3] as? NKUnifiedSharePropertyPassword)
        #expect(p3.type == .password)
        #expect(p3.hint == "Min 8 chars")

        let p4 = try #require(share.properties[4] as? NKUnifiedSharePropertyString)
        #expect(p4.type == .string)
        #expect(p4.minLength == 0)
        #expect(p4.maxLength == 1000)
    }

    @Test("Decodes both Icon shapes (svg / light+dark)")
    func decodesIconVariants() throws {
        let json = """
        {
          "ocs": {
            "meta": { "status": "ok", "statuscode": 200 },
            "data": {
              "id": "s2",
              "owner": {
                "user_id": "bob",
                "instance": null,
                "display_name": "Bob",
                "icon": { "svg": "<svg/>" }
              },
              "last_updated": 0,
              "state": "draft",
              "sources": [
                {
                  "class": "file",
                  "value": "/foo.txt",
                  "display_name": "foo.txt",
                  "icon": { "light": "https://x/light.png", "dark": "https://x/dark.png" }
                }
              ],
              "recipients": [],
              "permissions": [],
              "properties": []
            }
          }
        }
        """

        let share = try decodeShare(json: json)

        #expect(share.owner.icon.svg == "<svg/>")
        #expect(share.owner.icon.light == nil)
        let source = try #require(share.sources.first)
        #expect(source.icon?.svg == nil)
        #expect(source.icon?.light == "https://x/light.png")
        #expect(source.icon?.dark == "https://x/dark.png")
    }

    @Test("Decodes a list response via NKOCSWrapper<[NKUnifiedShare]>")
    func decodesShareListEnvelope() throws {
        let json = """
        {
          "ocs": {
            "meta": { "status": "ok", "statuscode": 200, "message": "OK" },
            "data": []
          }
        }
        """
        let wrap = try JSONDecoder().decode(NKOCSWrapper<[NKUnifiedShare]>.self, from: Data(json.utf8))
        #expect(wrap.ocs.meta.statuscode == 200)
        #expect(wrap.ocs.meta.message == "OK")
        #expect(wrap.ocs.data.isEmpty)
    }
}
