//
//  Conversation.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//
import SwiftData
import Foundation

@Model
final class Conversation {
    var id: UUID = UUID()
    var title: String = ""
    var lastActivityDate: Date = Date()
    var modelNameUsed: String?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage]? = []
    
    init(id: UUID = UUID(),
         title: String? = nil,
         lastActivityDate: Date = Date(),
         modelNameUsed: String? = nil,
         messages: [ChatMessage]? = []) {
        self.id = id
        self.lastActivityDate = lastActivityDate
        self.modelNameUsed = modelNameUsed
        self.messages = messages

        if let providedTitle = title, !providedTitle.isEmpty {
            self.title = providedTitle
        } else {
            self.title = "New Chat \(id.uuidString.prefix(4))"
        }
    }

    @MainActor
    func addMessage(_ message: ChatMessage, modelContext: ModelContext) {
        message.conversation = self
        if self.messages == nil {
            self.messages = []
        }
        self.messages?.append(message)
        lastActivityDate = Date()
    }

    @MainActor
    func updateTitleIfNeeded() {
        if let firstUserMessage = (messages)?.first(where: { Role(rawValue: $0.roleValue) == .user && !$0.content.isEmpty }) {
            let trimmedContent = firstUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let potentialTitle = String(trimmedContent.prefix(35))
            if !potentialTitle.isEmpty {
                self.title = potentialTitle + (trimmedContent.count > 35 ? "..." : "")
            }
        } else if title.starts(with: "New Chat") && (messages ?? []).isEmpty {
           self.title = "New Chat"
        }
    }
}

