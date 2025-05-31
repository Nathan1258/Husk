//
//  DisplayableConversationSection.swift
//  husk
//
//  Created by Nathan Ellis on 31/05/2025.
//


struct DisplayableConversationSection: Identifiable {
    let id: DateSectionGroup 
    var title: String { id.rawValue }
    var conversations: [Conversation]
}
