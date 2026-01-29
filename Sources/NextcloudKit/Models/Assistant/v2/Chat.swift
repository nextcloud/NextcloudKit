// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftyJSON

// MARK: - ChatMessage

public struct ChatMessage: Codable, Identifiable, Equatable {
    public let id: Int
    public let sessionId: Int
    public let role: String
    public let content: String
    public let timestamp: Int

    public var isFromHuman: Bool {
        role == "human"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case role
        case content
        case timestamp
    }
}

// MARK: - ChatMessageRequest

public struct ChatMessageRequest: Encodable {
    public let sessionId: Int
    public let role: String
    public let content: String
    public let timestamp: Int

    public init(sessionId: Int, role: String, content: String, timestamp: Int) {
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    var bodyMap: [String: Any] {
        return [
            "sessionId": sessionId,
            "role": role,
            "content": content,
            "timestamp": timestamp
        ]
    }

    enum CodingKeys: String, CodingKey {
        case sessionId
        case role
        case content
        case timestamp
    }
}

// MARK: - Conversation

public struct Conversation: Codable, Identifiable, Equatable {
    public let id: Int
    public let title: String?
    public let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case timestamp
    }
}

// MARK: - Session

public struct AssistantSession: Codable, Equatable {
    public let id: Int
    public let userId: String?
    private let title: String?
    public let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case timestamp
    }

    public var validTitle: String {
        return title ?? createTitle()

        func createTitle() -> String {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.timeZone = .current
            formatter.dateFormat = "MMM d yyyy, HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - CreateConversation

public struct CreateConversation: Codable, Equatable {
    public let session: AssistantSession

    enum CodingKeys: String, CodingKey {
        case session
    }
}
