//
//  ChatMessage.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//

import SwiftData
import Foundation
import OllamaKit

typealias Role = OKChatRequestData.Message.Role

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var roleValue: String = ""
    var content: String = ""
    var tokensPerSecond: Double? = nil
    var attachmentFileNames: [String]?
    var contentForLlm: String = ""
    var timestamp: Date = Date()

    var conversation: Conversation?
    
    var thinkingSteps: String? = nil
    var isShowingThinkingIndicator: Bool = false
    var displayPhase: String = MessageDisplayPhase.pending.rawValue
    

    @Transient var isStreaming: Bool = false

    var role: Role {
        get { Role(rawValue: roleValue) ?? .user }
        set { roleValue = newValue.rawValue }
    }

    init(id: UUID = UUID(),
         role: Role,
         content: String = "",
         contentForLlm: String = "",
         attachmentFileNames: [String]? = nil,
         timestamp: Date = Date(),
         conversation: Conversation? = nil,
         isStreaming: Bool = false) {
        self.id = id
        self.roleValue = role.rawValue
        self.content = content
        self.contentForLlm = contentForLlm
        self.attachmentFileNames = attachmentFileNames
        self.timestamp = timestamp
        self.conversation = conversation
        self.isStreaming = isStreaming
    }

    convenience init(role: Role,
                     typedText: String,
                     attachments: [(fileName: String, fileContent: String)]? = nil,
                     timestamp: Date = Date()) {
        let uiText = typedText
        var llmText = typedText
        var resolvedAttachmentFileNames: [String]? = nil

        if let atts = attachments, !atts.isEmpty {
            resolvedAttachmentFileNames = atts.map { $0.fileName }
            let fullFileTexts = atts.map { "\n\n--- Attached File: \($0.fileName) ---\n\($0.fileContent)" }.joined()
            llmText += fullFileTexts
        }

        self.init(role: role, content: uiText, contentForLlm: llmText, attachmentFileNames: resolvedAttachmentFileNames, timestamp: timestamp)
    }

    convenience init(role: Role, content: String, isStreaming: Bool = false, timestamp: Date = Date()) {
        self.init(role: role, content: content, contentForLlm: content, timestamp: timestamp, isStreaming: isStreaming)
    }
}
