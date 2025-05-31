//
//  ChatManager.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//
import Foundation
import OllamaKit
import Combine
import SwiftUI
import SwiftData


@MainActor
class ChatManager: ObservableObject {
    
    private var modelContext: ModelContext
    
    @Published var availableModels: [LanguageModel] = []
    @Published var isLoading: Bool = true
    @Published var isReplying: Bool = false
    
    @Published var reachable: Bool = false
    @Published var errorMessage: String? = nil
    
    @Published var conversations: [Conversation] = []
    @Published var activeConversation: Conversation?
    
    @Published var currentStreamingMessageContent: String = ""
    
    private var ollama: OllamaKit
    
    private var reachabilitySubscription: AnyCancellable?
    private let reachabilityCheckInterval: TimeInterval = 10.0
    private var cancellables = Set<AnyCancellable>()
    
    private var currentStreamingTask: Task<Void, Error>? = nil
    
    @AppStorage("ollamaURL") var ollamaHost: String = "http://localhost"
    @AppStorage("ollamaPort") var ollamaPort: String = "11434"
    
    private var currentUserName: String {
        UserDefaults.standard.string(forKey: "userNameForPersonalisation") ?? ""
    }

    private var currentGlobalSystemPrompt: String {
        UserDefaults.standard.string(forKey: "globalSystemPrompt") ?? ""
    }
    
    private var shouldUseLLMForTitles: Bool {
        UserDefaults.standard.bool(forKey: "useLLMToCreateTitles")
    }

    init(modelContext: ModelContext){
        self.modelContext = modelContext
        
        var initialBaseURL: URL
        let combinedURLString = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost"
        let port = UserDefaults.standard.string(forKey: "ollamaPort") ?? "11434"
        let fullURLString = "\(combinedURLString):\(port)"
        
        if let url = URL(string: fullURLString), url.scheme != nil {
            initialBaseURL = url
        } else {
            print("Warning: Stored values were invalid. Using default.")
            initialBaseURL = URL(string: "http://localhost:11434")!
        }
        
        self.ollama = OllamaKit(baseURL: initialBaseURL)
        
        Task {
            fetchConversations()
            await refreshModels()
            setupContinuousReachabilityListener()
            if self.activeConversation == nil {
                if self.conversations.isEmpty {
                    self.createNewConversation()
                } else {
                    self.activeConversation = self.conversations.first
                }
            }
        }
    }
    
    private func fetchConversations() {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\Conversation.lastActivityDate, order: .reverse)]
        )
        do {
            self.conversations = try modelContext.fetch(descriptor)
            print("SwiftData: Loaded \(self.conversations.count) conversations.")
        } catch {
            print("SwiftData: Failed to fetch conversations: \(error)")
            self.errorMessage = "Could not load conversations: \(error.localizedDescription)"
            self.conversations = []
        }
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
            print("SwiftData: Context saved.")
        } catch {
            print("SwiftData: Failed to save context: \(error)")
            self.errorMessage = "Could not save changes: \(error.localizedDescription)"
        }
    }
    
    func createNewConversation(modelName: String? = nil) {
        let conversationCreationDate = Date()
        
        let newConversation = Conversation(
            title: nil,
            lastActivityDate: Date(),
            modelNameUsed: modelName ?? availableModels.first?.name,
            messages: []
        )
        newConversation.updateTitleIfNeeded()
        
        modelContext.insert(newConversation)
        let userName = self.currentUserName
        let globalPrompt = self.currentGlobalSystemPrompt
        var effectiveSystemPromptContent = globalPrompt
        
        if !userName.isEmpty {
            if effectiveSystemPromptContent.isEmpty {
                effectiveSystemPromptContent = "You are a helpful assistant. The user you are speaking to is named \(userName). Please be friendly and address them by name when appropriate. The user may enter their full name, use their first name at all times."
            } else {
                effectiveSystemPromptContent += " You are interacting with a user named \(userName)."
            }
        }
        
        if !effectiveSystemPromptContent.isEmpty {
            let systemMessage = ChatMessage(
                role: .system,
                content: effectiveSystemPromptContent,
                contentForLlm: effectiveSystemPromptContent,
                timestamp: conversationCreationDate
            )
            
            modelContext.insert(systemMessage)
            
            newConversation.addMessage(systemMessage, modelContext: self.modelContext)
        }
        
        saveContext()
        
        var updatedConversations = self.conversations
        if !updatedConversations.contains(where: { $0.id == newConversation.id }) {
            updatedConversations.insert(newConversation, at: 0)
        }
        self.conversations = updatedConversations.sorted(by: { $0.lastActivityDate > $1.lastActivityDate })
        
        self.activeConversation = newConversation
        
    }
    
    func selectConversation(_ conversation: Conversation) {
        activeConversation = conversation
    }
    
    func deleteConversation(_ conversationToDelete: Conversation) {
        let isActiveBeingDeleted = activeConversation?.id == conversationToDelete.id
        
        modelContext.delete(conversationToDelete)
        saveContext()
        
        withAnimation(.spring()) {
            conversations.removeAll { $0.id == conversationToDelete.id }
            if isActiveBeingDeleted {
                activeConversation = conversations.first
            }
        }
    }
    
    func clearAllConversations() {
        do {
            try modelContext.delete(model: Conversation.self)
            saveContext()
            
            print("SwiftData: All conversations cleared.")
            conversations = []
            activeConversation = nil
            createNewConversation()
        } catch {
            print("SwiftData: Failed to clear all conversations: \(error)")
            errorMessage = "Could not clear all chats: \(error.localizedDescription)"
        }
    }

    
    func setupContinuousReachabilityListener() {
        Task {
            let initialStatus = await self.performOllamaReachabilityCheck()
            await MainActor.run {
                self.reachable = initialStatus
                self.isLoading = false
                print("Initial Ollama reachability status: \(self.reachable)")
                self.handleReachabilityChange(status: initialStatus)
            }
        }
        
        Timer.publish(every: reachabilityCheckInterval, on: .main, in: .common)
            .autoconnect()
            .flatMap { [weak self] _ -> AnyPublisher<Bool, Never> in
                guard let self = self else {
                    return Empty(completeImmediately: true).eraseToAnyPublisher()
                }
                return Future<Bool, Never> { promise in
                    Task {
                        let status = await self.performOllamaReachabilityCheck()
                        promise(.success(status))
                    }
                }
                .eraseToAnyPublisher()
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReachableStatus in
                guard let self = self else { return }
                self.reachable = isReachableStatus
                print("Periodic Ollama reachability status updated to: \(self.reachable)")
                self.handleReachabilityChange(status: isReachableStatus)
            }
            .store(in: &cancellables)
    }
    
    private func performOllamaReachabilityCheck() async -> Bool {
        return await ollama.reachable()
    }
    
    private func handleReachabilityChange(status: Bool) {
        if status {
            if self.availableModels.isEmpty && !self.isLoading {
                print("Ollama became reachable, and models are missing. Refreshing models...")
                Task {
                    await self.refreshModels()
                }
            }
        } else {
            print("Ollama is unreachable.")
        }
    }
    
    func refreshModels() async {
        do {
            let response = try await ollama.models()
            self.availableModels = response.models.sorted { $0.name < $1.name }
                .map { LanguageModel(name: $0.name, provider: .ollama) }
        } catch {
            print("Error fetching models: \(error.localizedDescription)")
            self.errorMessage = "Could not fetch models: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func generateAndSetConversationTitle(for conversation: Conversation, usingModel modelName: String) async {
        guard let conversationToUpdate = self.conversations.first(where: { $0.id == conversation.id }),
              conversationToUpdate.title.starts(with: "New Chat") || conversationToUpdate.title.isEmpty else {
            print("Title generation skipped: Conversation already has a custom title or doesn't exist.")
            return
        }
        
        let messagesForTitleContext = (conversationToUpdate.messages ?? [])
            .filter { Role(rawValue: $0.roleValue) != .system }
            .sorted { $0.timestamp < $1.timestamp }
            .prefix(4)
        
        guard messagesForTitleContext.count >= 1 else {
            print("Title generation skipped: Not enough context messages.")
            conversationToUpdate.updateTitleIfNeeded()
            saveContext()
            return
        }
        
        var contextString = "Based on the following conversation excerpt, suggest a very short, concise title (ideally 3-5 words, maximum 7 words). Output ONLY the title itself, with no extra text, quotation marks, or labels like 'Title:'.\n\nExcerpt:\n"
        for message in messagesForTitleContext {
            let rolePrefix = (Role(rawValue: message.roleValue) ?? .user) == .user ? "User:" : "Assistant:"
            contextString += "\(rolePrefix) \(message.content)\n"
        }
        contextString += "\nTitle:"
        
        print("Attempting to generate title with prompt: \(contextString)")
        
        let requestData = OKGenerateRequestData(model: modelName, prompt: contextString)
        
        do {
            var generatedTitleChars: [String] = []
            let responseStream = ollama.generate(data: requestData)
            
            for try await generateResponse in responseStream {
                generatedTitleChars.append(generateResponse.response)
                if generateResponse.done {
                    break
                }
            }
            
            var generatedTitle = generatedTitleChars.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if generatedTitle.hasPrefix("\"") && generatedTitle.hasSuffix("\"") {
                generatedTitle = String(generatedTitle.dropFirst().dropLast())
            }
            generatedTitle = generatedTitle.replacingOccurrences(of: "Title:", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
            
            
            if !generatedTitle.isEmpty && generatedTitle.lowercased() != "no title" && generatedTitle.lowercased() != "untitled" {
                print("LLM generated title: \(generatedTitle)")
                conversationToUpdate.title = generatedTitle
                conversationToUpdate.lastActivityDate = Date()
                saveContext()
            } else {
                print("LLM returned empty or unsuitable title. Falling back to default title generation.")
                conversationToUpdate.updateTitleIfNeeded()
                saveContext()
            }
        } catch {
            print("Failed to generate title using LLM: \(error). Falling back to default title generation.")
            conversationToUpdate.updateTitleIfNeeded()
            saveContext()
        }
    }
    
    func sendMessage(
        typedText: String,
        attachmentDetails: (fileName: String, fileContent: String)?,
        modelName: String
    ) async throws {
        guard let currentConversation = activeConversation else {
            throw ChatManagerError.noActiveConversation
        }
        
        currentStreamingTask?.cancel()
        
        currentConversation.modelNameUsed = modelName
        currentConversation.lastActivityDate = Date()
        
        self.isReplying = true
        self.errorMessage = nil
        
        let userAttachments = attachmentDetails != nil ? [(fileName: attachmentDetails!.fileName, fileContent: attachmentDetails!.fileContent)] : nil
        let userMessage = ChatMessage(role: .user, typedText: typedText, attachments: userAttachments)
        currentConversation.addMessage(userMessage, modelContext: modelContext)
        
        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        currentConversation.addMessage(assistantMessage, modelContext: modelContext)
        
        saveContext()
        
        self.currentStreamingMessageContent = ""
        
        let historyForOllama: [OKChatRequestData.Message] = (currentConversation.messages ?? []).compactMap { msgModel in
            guard let role = Role(rawValue: msgModel.roleValue) else { return nil }
            return OKChatRequestData.Message(role: role, content: msgModel.contentForLlm, images: nil)
        }
        
        let chatRequestData = OKChatRequestData(model: modelName, messages: historyForOllama)
        
        let streamingTask = Task{
            var accumulatedContentForCurrentResponse = ""
            var unbatchedChunkBuffer = ""
            let batchThreshold = 30
            var lastUpdateTime = Date()
            let minTimeIntervalForUpdate: TimeInterval = 0.2
            
            do {
                let responseStream: AsyncThrowingStream<OKChatResponse, Error> = ollama.chat(data: chatRequestData)
                
                for try await streamedResponse in responseStream {
                    
                    try Task.checkCancellation()
                    if let contentPiece = streamedResponse.message?.content {
                        unbatchedChunkBuffer += contentPiece
                        let now = Date()
                        if unbatchedChunkBuffer.count >= batchThreshold || now.timeIntervalSince(lastUpdateTime) >= minTimeIntervalForUpdate {
                            accumulatedContentForCurrentResponse += unbatchedChunkBuffer
                            assistantMessage.content = accumulatedContentForCurrentResponse
                            self.currentStreamingMessageContent = accumulatedContentForCurrentResponse
                            unbatchedChunkBuffer = ""
                            lastUpdateTime = now
                        }
                    }
                }
                
                if !unbatchedChunkBuffer.isEmpty {
                    accumulatedContentForCurrentResponse += unbatchedChunkBuffer
                    assistantMessage.content = accumulatedContentForCurrentResponse
                    self.currentStreamingMessageContent = accumulatedContentForCurrentResponse
                }
                
                assistantMessage.isStreaming = false
                
                currentConversation.lastActivityDate = Date()
                
                self.isReplying = false
                self.currentStreamingMessageContent = ""
                
                saveContext()
                if shouldUseLLMForTitles {
                    let messageCountForTitle = (currentConversation.messages ?? [])
                        .filter { Role(rawValue: $0.roleValue) != .system }
                        .count
                    
                    if (currentConversation.title.starts(with: "New Chat") || currentConversation.title.isEmpty) && messageCountForTitle >= 2 {
                        Task {
                            await generateAndSetConversationTitle(for: currentConversation, usingModel: modelName)
                        }
                    }
                } else {
                    if currentConversation.title.starts(with: "New Chat") || currentConversation.title.isEmpty {
                        currentConversation.updateTitleIfNeeded()
                        saveContext()
                    }
                }
                print("SwiftData: Message stream finished, conversation updated and saved.")
                
            }catch is CancellationError{
                print("Streaming task was cancelled by user.")
                assistantMessage.content += "\n\n*(Response stopped by user)*"
                assistantMessage.isStreaming = false
            } catch {
                assistantMessage.content += "\n\n*(Error during response: \(error.localizedDescription))*"
                assistantMessage.isStreaming = false
                self.errorMessage = "Ollama request failed: \(error.localizedDescription)"
                throw error
            }
        }
        
        
        self.currentStreamingTask = streamingTask
        
        do {
            defer {
                Task {
                    await MainActor.run {
                        currentConversation.lastActivityDate = Date()
                        currentConversation.updateTitleIfNeeded()
                        self.isReplying = false
                        self.currentStreamingMessageContent = ""
                        self.currentStreamingTask = nil
                    }
                    saveContext()
                    print("sendMessage finished, context saved, isReplying: \(self.isReplying)")
                }
            }
            
            try await streamingTask.value
        } catch is CancellationError {
            print("sendMessage awaited task was cancelled.")
        } catch {
            print("sendMessage awaited task failed with error: \(error)")
            if let chatError = error as? ChatManagerError {
                throw chatError
            } else {
                throw ChatManagerError.requestFailed(underlyingError: error)
            }
        }
    }
    
    @MainActor
    func stopGeneratingResponse() {
        print("Stop generating response called.")
        guard let task = currentStreamingTask, !task.isCancelled else {
            print("No active cancellable task, or task already cancelled.")
            if isReplying {
                isReplying = false
                currentStreamingMessageContent = ""
            }
            return
        }
        task.cancel()
    }
}
