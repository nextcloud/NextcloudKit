// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

/// Exact server identity for a recipient, optionally scoped to one unified share.
struct UnifiedShareRecipientIdentity: Hashable {
    let shareID: String?
    let recipientClass: String
    let value: String
    let instance: String?

    init(shareID: String? = nil, recipient: NKUnifiedShareRecipient) {
        self.shareID = shareID
        self.recipientClass = recipient.class
        self.value = recipient.value
        self.instance = recipient.instance
    }
}

extension NKUnifiedShareRecipient {
    var unifiedShareIdentity: UnifiedShareRecipientIdentity {
        UnifiedShareRecipientIdentity(recipient: self)
    }
}
