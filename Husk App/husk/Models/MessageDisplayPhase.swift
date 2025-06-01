//
//  MessageDisplayPhase.swift
//  husk
//
//  Created by Nathan Ellis on 01/06/2025.
//


enum MessageDisplayPhase: String {
    case pending // Message created, no stream yet
    case thinking // Actively processing <think> tag content
    case answering // Actively processing answer content
    case complete // Stream finished
}