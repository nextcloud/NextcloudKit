// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

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

    public init(id: Int, sessionId: Int, role: String, content: String, timestamp: Int) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.timestamp = timestamp
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
    public let firstHumanMessage: Bool

    public init(sessionId: Int, role: String, content: String, timestamp: Int, firstHumanMessage: Bool) {
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.firstHumanMessage = firstHumanMessage
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
        case firstHumanMessage
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

public struct AssistantConversation: Codable, Equatable, Hashable {
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
    public let conversation: AssistantConversation

    enum CodingKeys: String, CodingKey {
        case conversation = "session"
    }
}

// MARK: - SessionTask

public struct SessionTask: Codable, Equatable {
    public let taskId: Int

    enum CodingKeys: String, CodingKey {
        case taskId
    }
}
