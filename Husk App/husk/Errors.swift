//
//  Errors.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//

import Foundation
import Combine

enum ChatManagerError: Error, LocalizedError {
    case messageEmpty
    case modelNameEmpty
    case serverUnreachable
    case noContentInResponse
    case noActiveConversation
    case requestFailed(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .messageEmpty:
            return "Message text cannot be empty."
        case .modelNameEmpty:
            return "Model name cannot be empty."
        case .serverUnreachable:
            return "Ollama server is not currently reachable. Please check the connection and try again."
        case .noActiveConversation:
            return "No active conversation found. Please start a new conversation."
        case .noContentInResponse:
            return "The model did not provide any content in its response."
        case .requestFailed(let underlyingError):
            return "Failed to get response from the model: \(underlyingError.localizedDescription)"
        }
    }
}
