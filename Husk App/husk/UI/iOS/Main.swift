//
//  Main.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//

import SwiftUI
import MarkdownUI

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Main View
struct Main: View {
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var speechManager: SpeechToTextManager
    @EnvironmentObject var attachmentManager: AttachmentManager
    
    @State private var selectedModel: LanguageModel?
    @State private var animateGradient = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var messageText = ""
    @State private var chatInputBarHeight: CGFloat = 50
    @State private var showSheet = false
    @State private var showLeftSidebar = false
    @State private var path = NavigationPath()
    
    @AppStorage("userNameForPersonalisation") private var userName: String = ""
    
    @State private var glowRadius: CGFloat = 5
    
    private var sidebarWidth: CGFloat {
        min(UIScreen.main.bounds.width * 0.85, 300)
    }
    
    private var currentMessages: [ChatMessage] {
        guard let activeConvo = chatManager.activeConversation,
              let msgs = activeConvo.messages else {
            return []
        }
        let sortedMessages = msgs.sorted { $0.timestamp < $1.timestamp }
        
        if let firstMessage = sortedMessages.first,
           firstMessage.role == .system {
            return Array(sortedMessages.dropFirst())
        }
        return sortedMessages
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                if chatManager.reachable {
                    mainView
                } else {
                    unreachableView
                }
            }
            .navigationDestination(for: SettingsPath.self) { path in
                ConnectionsView()
            }
            .sheet(isPresented: $showSheet) {
                Settings()
                    .presentationBackground(.ultraThinMaterial)
            }
            .onAppear { setupInitialState() }
            .onChange(of: chatManager.availableModels) { handleAvailableModelsChange() }
            .onChange(of: chatManager.activeConversation) { handleActiveConversationChange() }
            .onChange(of: selectedModel) { handleSelectedModelChange() }
        }
    }
    
    // MARK: - Main Content
    private var mainView: some View {
        ZStack(alignment: .leading) {
            LeftSidebarView(
                isPresented: $showLeftSidebar,
                showSettingsSheet: $showSheet,
                selectedModelForNewChat: $selectedModel
            )
            .environmentObject(chatManager)
            .frame(width: sidebarWidth)
            
            mainContentAndInput
                .frame(width: UIScreen.main.bounds.width)
                .background(Color(UIColor.systemBackground))
                .offset(x: showLeftSidebar ? sidebarWidth : 0)
                .disabled(showLeftSidebar)
                .shadow(color: showLeftSidebar ? Color.black.opacity(0.2) : Color.clear, radius: 10, x: -5, y: 0)
                .onTapGesture { handleMainContentTap() }
                
            if showLeftSidebar {
                Color.black.opacity(0.001)
                    .frame(width: UIScreen.main.bounds.width - sidebarWidth)
                    .offset(x: sidebarWidth)
                    .contentShape(Rectangle())
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showLeftSidebar)
        .toolbar {
            leadingToolbarItems
            principalToolbarItems
            trailingToolbarItems
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(showLeftSidebar)
    }
    
    private var unreachableView: some View {
        VStack(alignment: .center, spacing: 20) {
            if chatManager.isLoading {
                ProgressView()
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                Text("Ollama Unreachable")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding(.bottom)
                
                Button("Check connection settings") {
                    path.append(SettingsPath.connections)
                }
            }
        }
    }
    
    // MARK: - Content Area
    var mainContentAndInput: some View {
        ZStack(alignment: .bottom) {
            contentView
            
            if chatManager.activeConversation != nil {
                chatInputBar
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if chatManager.activeConversation == nil && !chatManager.isLoading {
            noConversationView
        } else if currentMessages.isEmpty && !(chatManager.activeConversation?.messages?.contains(where: {$0.isStreaming}) ?? false) {
            welcomeMessage
        } else {
            messagesScrollView
        }
    }
    
    private var noConversationView: some View {
        VStack {
            Text("No Conversation Selected")
                .font(.title)
                .foregroundColor(.gray)
            Text("Create a new chat or select one from the sidebar.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
            Button {
                chatManager.createNewConversation(modelName: selectedModel?.name)
                showLeftSidebar = false
            } label: {
                Label("Start New Chat", systemImage: "plus.message.fill")
                    .padding()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack {
                    ForEach(currentMessages, id: \.id) { message in
                        MessageView(message: message)
                            .padding()
                            .id(message.id)
                    }
                    Color.clear
                        .frame(height: chatInputBarHeight)
                        .id("BOTTOM_ANCHOR")
                }
                .onChange(of: currentMessages.count) { scrollToLastMessage() }
                .onChange(of: chatManager.currentStreamingMessageContent) {
                    if currentMessages.last?.isStreaming == true {
                        scrollToLastMessage()
                    }
                }
                .onAppear {
                    self.scrollProxy = scrollViewProxy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToLastMessage()
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private var chatInputBar: some View {
        ChatInputBar(
            text: $messageText,
            onSend: { sendMessage(typedText: $0) },
            isReplying: chatManager.isReplying
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
            if self.chatInputBarHeight != newHeight {
                self.chatInputBarHeight = newHeight
                scrollToLastMessage()
            }
        }
    }
    
    @ViewBuilder
    private var welcomeMessage: some View {
        VStack(alignment: .center, spacing: 10) {
            Spacer()
            let greeting = getGreeting()
            let greetingTextView = Text(greeting)
                .font(.system(size: 48, weight: .bold))
                .multilineTextAlignment(.center)
            
            LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.indigo]),
                startPoint: animateGradient ? UnitPoint(x: 0, y: 0) : UnitPoint(x: 1, y: 1),
                endPoint: animateGradient ? UnitPoint(x: 1, y: 1) : UnitPoint(x: 0, y: 0)
            )
            .mask(greetingTextView)
            .drawingGroup()
            .shadow(color: .purple.opacity(0.7), radius: glowRadius, x: 0, y: 0)
            .shadow(color: .indigo.opacity(0.5), radius: glowRadius * 1.5, x: 0, y: 0)
            .shadow(color: .purple.opacity(0.3), radius: glowRadius * 2, x: 0, y: 0)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glowRadius)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
                glowRadius = 20
            }
            Spacer()
        }
    }
    
    // MARK: - Toolbar Items
    @ToolbarContentBuilder
    private var leadingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showLeftSidebar.toggle()
                }
            }) {
                Image(systemName: showLeftSidebar ? "xmark" : "bubble")
                    .font(.system(size: 18))
                    .frame(width: 22, height: 22, alignment: .center)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var principalToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if chatManager.reachable {
                modelSelectionMenu
            } else {
                unreachableToolbarItem
            }
        }
    }
    
    private var modelSelectionMenu: some View {
        Menu {
            if chatManager.availableModels.isEmpty {
                Text("No models downloaded")
                    .disabled(true)
            } else {
                ForEach(chatManager.availableModels, id: \.self) { model in
                    Button(action: { selectedModel = model }) {
                        Text(model.name)
                        if selectedModel == model {
                            Spacer()
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 1) {
                Text(selectedModel?.name ?? "Select Model").font(.title2.bold()).foregroundColor(.accent)
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .padding(.bottom, 6)
        }
    }
    
    private var unreachableToolbarItem: some View {
        HStack(spacing: 2) {
            Text("Ollama Unreachable").font(.headline).foregroundColor(.red)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .onTapGesture {
            path.append(SettingsPath.connections)
        }
    }
    
    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                chatManager.createNewConversation(modelName: selectedModel?.name)
            }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18))
                    .frame(width: 22, height: 22, alignment: .center)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func setupInitialState() {
        if selectedModel == nil {
            initializeSelectedModel()
        }
        speechManager.refreshAvailability()
    }
    
    private func initializeSelectedModel() {
        if let activeConvModelName = chatManager.activeConversation?.modelNameUsed,
           let model = chatManager.availableModels.first(where: { $0.name == activeConvModelName }) {
            selectedModel = model
        } else if let firstModel = chatManager.availableModels.first {
            selectedModel = firstModel
            if chatManager.activeConversation?.modelNameUsed == nil {
                chatManager.activeConversation?.modelNameUsed = firstModel.name
            }
        }
    }
    
    private func handleAvailableModelsChange() {
        let newModelsList = chatManager.availableModels
        let firstModel = newModelsList.first
        
        func modelExists(_ modelName: String?) -> Bool {
            guard let name = modelName else { return false }
            return newModelsList.contains { $0.name == name }
        }
        
        if !modelExists(selectedModel?.name) {
            selectedModel = firstModel
        }
        
        if let activeConv = chatManager.activeConversation,
           !modelExists(activeConv.modelNameUsed) {
            activeConv.modelNameUsed = firstModel?.name
        }
    }
    
    private func handleActiveConversationChange() {
        let availableModels = chatManager.availableModels
        let firstModel = availableModels.first
        
        func findModel(named modelName: String?) -> LanguageModel? {
            guard let name = modelName else { return nil }
            return availableModels.first { $0.name == name }
        }
        
        if let conversation = chatManager.activeConversation {
            if let existingModel = findModel(named: conversation.modelNameUsed) {
                selectedModel = existingModel
            } else {
                selectedModel = firstModel
                conversation.modelNameUsed = firstModel?.name
            }
        } else {
            selectedModel = firstModel
        }
        
        scrollToLastMessage()
    }
    
    private func handleSelectedModelChange() {
        if let activeConv = chatManager.activeConversation, let newName = selectedModel?.name {
            if activeConv.modelNameUsed != newName {
                activeConv.modelNameUsed = newName
            }
        }
    }
    
    private func handleMainContentTap() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        if showLeftSidebar {
            showLeftSidebar = false
        }
    }
    
    private func scrollToLastMessage() {
        DispatchQueue.main.async {
            withAnimation {
                scrollProxy?.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
            }
        }
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning\(userName.isEmpty ? "" : ", \(userName)")"
        case 12..<17: return "Good Afternoon\(userName.isEmpty ? "" : ", \(userName)")"
        default: return "Good Evening\(userName.isEmpty ? "" : ", \(userName)")"
        }
    }
    
    private func sendMessage(typedText: String) {
        guard let model = selectedModel else {
            print("No model selected.")
            chatManager.errorMessage = "Please select a model first."
            return
        }
        
        guard chatManager.activeConversation != nil else {
            print("Cannot send message: No active conversation.")
            chatManager.errorMessage = "Please start or select a conversation."
            return
        }
        
        var attachmentData: (fileName: String, fileContent: String)?
        if let fileName = attachmentManager.selectedFileName,
           let fileContent = attachmentManager.importedFileContent {
            attachmentData = (fileName: fileName, fileContent: fileContent)
        }
        
        Task {
            do {
                await MainActor.run {
                    messageText = ""
                    if attachmentData != nil {
                        attachmentManager.clearAttachment()
                    }
                }
                
                try await chatManager.sendMessage(
                    typedText: typedText,
                    attachmentDetails: attachmentData,
                    modelName: model.name
                )
            } catch let error as ChatManagerError {
                print("\(error.localizedDescription)")
            } catch {
                print("\(error.localizedDescription)")
                await MainActor.run {
                    chatManager.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Sidebar View
struct LeftSidebarView: View {
    @Binding var isPresented: Bool
    @Binding var showSettingsSheet: Bool
    @EnvironmentObject var chatManager: ChatManager
    @Binding var selectedModelForNewChat: LanguageModel?
    
    @State private var showingDeleteConfirmation = false
    @State private var conversationToDelete: Conversation?
    
    @State private var searchText = ""
    
    var filteredConversations: [Conversation] {
        let sortedConversations = chatManager.conversations.sorted(by: { $0.lastActivityDate > $1.lastActivityDate })
        
        if searchText.isEmpty {
            return sortedConversations
        } else {
            return sortedConversations.filter { conversation in
                let titleMatch = conversation.title.localizedCaseInsensitiveContains(searchText)
                let messageMatch = conversation.messages?.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
                }
                return titleMatch || (messageMatch != nil)
            }
        }
    }
    
    var conversationSections: [DisplayableConversationSection] {
        let now = Date()
        let calendar = Calendar.current
        
        let groupedDictionary = Dictionary(grouping: filteredConversations) { conversation in
            categorise(date: conversation.lastActivityDate, calendar: calendar, now: now)
        }
        
        return groupedDictionary.map { (dateGroup, conversations) in
            DisplayableConversationSection(id: dateGroup, conversations: conversations)
        }
        .sorted { $0.id.displayOrder < $1.id.displayOrder }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            conversationsList
            Spacer()
            footerSection
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search Conversations", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var conversationsList: some View {
        List {
            ForEach(conversationSections) { section in
                Section(header: Text(section.title).font(.headline)) {
                    ForEach(section.conversations) { conversation in
                        ConversationRowView(
                            conversation: conversation,
                            isActive: chatManager.activeConversation?.id == conversation.id,
                            onSelect: {
                                chatManager.selectConversation(conversation)
                                isPresented = false
                            }
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                conversationToDelete = conversation
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete Chat", systemImage: "trash.fill")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                conversationToDelete = conversation
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
                .padding(.horizontal, -10)
            }
        }
        .listStyle(PlainListStyle())
        .alert("Delete Conversation?", isPresented: $showingDeleteConfirmation, presenting: conversationToDelete) { convToDelete in
            Button("Delete", role: .destructive) {
                chatManager.deleteConversation(convToDelete)
                conversationToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                conversationToDelete = nil
            }
        } message: { convToDelete in
            Text("Are you sure you want to delete the chat titled \"\(convToDelete.title)\"? This cannot be undone.")
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: {
                isPresented = false
                showSettingsSheet = true
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .padding()
            }
            .foregroundColor(.primary)
        }
    }
    
    private func categorise(date: Date, calendar: Calendar = .current, now: Date = Date()) -> DateSectionGroup {
        let startOfToday = calendar.startOfDay(for: now)
        
        if calendar.isDate(date, inSameDayAs: startOfToday) {
            return .today
        }
        
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        if calendar.isDate(date, inSameDayAs: startOfYesterday) {
            return .yesterday
        }
        
        let sevenDaysAgoBoundary = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
        if date < startOfYesterday && date >= sevenDaysAgoBoundary {
            return .previous7Days
        }
        
        let thirtyDaysAgoBoundary = calendar.date(byAdding: .day, value: -30, to: startOfToday)!
        if date < sevenDaysAgoBoundary && date >= thirtyDaysAgoBoundary {
            return .previous30Days
        }
        
        return .older
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(conversation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(isActive ? .white : .primary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isActive ? Color.accentColor : Color.clear
            )
            .contentShape(Rectangle())
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Message View
struct MessageView: View {
    let message: ChatMessage
    @State private var isThinkingExpanded: Bool = false
    @AppStorage("showTokenPerSeconds") private var showTokenPerSeconds: Bool = true
    
    
    var body: some View {
        let isUserMessage = message.role == .user
        let currentDisplayPhase = MessageDisplayPhase(rawValue: message.displayPhase) ?? .pending
        
        let showThinkingIndicatorActive = currentDisplayPhase == .thinking && message.isStreaming
        
        let assistantAnswerText = (currentDisplayPhase == .answering || currentDisplayPhase == .complete) ? message.content : ""
        
        HStack {
            if isUserMessage { Spacer(minLength: 20) }
            
            VStack(alignment: .leading, spacing: 8) {
                if isUserMessage, let fileNames = message.attachmentFileNames, !fileNames.isEmpty {
                    ForEach(fileNames, id: \.self) { fileName in
                        attachmentView(fileName: fileName)
                    }
                }
                
                if isUserMessage {
                    let userDisplayedText = message.content.isEmpty && message.isStreaming ? "..." : message.content
                    if !userDisplayedText.isEmpty {
                        Markdown(userDisplayedText)
                    }
                } else {
                    if showThinkingIndicatorActive {
                        ThinkingShimmerView()
                    }
                    
                    if currentDisplayPhase == .complete, let thinkingText = message.thinkingSteps, !thinkingText.isEmpty {
                        DisclosureGroup(isExpanded: $isThinkingExpanded) {
                            Markdown(thinkingText)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        } label: {
                            Text("Show Thinking Process")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, assistantAnswerText.isEmpty && !showThinkingIndicatorActive ? 0 : 8)
                    }
                    if !assistantAnswerText.isEmpty {
                        Markdown(assistantAnswerText)
                            .id("answer_\(message.id)")
                    } else if message.isStreaming && !showThinkingIndicatorActive && assistantAnswerText.isEmpty && currentDisplayPhase != .complete {
                        Text("...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                if !isUserMessage, currentDisplayPhase == .complete, let tps = message.tokensPerSecond, showTokenPerSeconds {
                    Text(String(format: "%.2f t/s", tps))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
            }
            .padding(10)
            .foregroundColor(.white)
            .background {
                if isUserMessage {
                    Rectangle().fill(.ultraThinMaterial)
                } else {
                    Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if !isUserMessage { Spacer(minLength: 20) }
        }
        .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)
        .animation(message.isStreaming ? .default : nil, value: message.content)
    }
    
    private func attachmentView(fileName: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.callout)
                .foregroundColor(Color.white.opacity(0.7))
            Text(fileName)
                .font(.caption.weight(.medium))
                .foregroundColor(Color.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ThinkingShimmerView: View {
    @State private var shimmerPosition: CGFloat = -1.5

    var body: some View {
        Text("Thinking...")
            .font(.headline)
            .foregroundColor(.gray)
            .opacity(0.7)
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color.white.opacity(0.6), location: 0.4),
                        .init(color: Color.white.opacity(0.6), location: 0.6),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .scaleEffect(x: 1.5, y: 1.5)
                .offset(x: shimmerPosition * 200)
                .mask(Text("Thinking...").font(.headline))
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPosition = 1.5
                }
            }
    }
}

// MARK: - Chat Input Bar
struct ChatInputBar: View {
    @EnvironmentObject var speechManager: SpeechToTextManager
    @EnvironmentObject var attachmentManager: AttachmentManager
    @EnvironmentObject var chatManager: ChatManager
    
    @Binding var text: String
    let onSend: (String) -> Void
    var isReplying: Bool
    
    @State private var animationPhase: Double = 0.0
    @State private var gradientStartPoint: UnitPoint = .top
    @State private var gradientEndPoint: UnitPoint = .bottom
    
    private var cantSend: Bool {
        (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
         attachmentManager.importedFileContent == nil) || isReplying
    }
    
    var body: some View {
        VStack(spacing: 0) {
            attachmentSection
            textInputSection
        }
        .background(backgroundView)
        .overlay(borderOverlay)
        .shadow(color: .purple.opacity(0.125 + animationPhase * 0.2), radius: 15 + animationPhase * 5, y: -8)
        .shadow(color: .indigo.opacity(0.0625 + animationPhase * 0.1), radius: 10, y: -4)
        .shadow(color: .black.opacity(0.08), radius: 8, y: -4)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .onAppear { startAnimations() }
        .task { await animateGradientPoints() }
        .onChange(of: speechManager.transcribedText) {
            text = speechManager.transcribedText
        }
        .fileImporter(
            isPresented: $attachmentManager.showFileImporter,
            allowedContentTypes: attachmentManager.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            attachmentManager.handleFileImport(result: result)
        }
    }
    
    @ViewBuilder
    private var attachmentSection: some View {
        if let fileName = attachmentManager.selectedFileName {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.gray)
                Text(fileName)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Button {
                    attachmentManager.clearAttachment()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
    
    private var textInputSection: some View {
        HStack(alignment: .center, spacing: 6){
            attachmentMenu
            TextField("Ask anything", text: $text, axis: .vertical)
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                .onSubmit { if !isReplying { prepareAndSendMessage() } }
            Spacer()
            if text.isEmpty{
                microphoneButton
            }else{
                if chatManager.isReplying{
                    stopButton
                } else {
                    sendButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private var attachmentMenu: some View {
        Menu {
            Button(action: { attachmentManager.selectFile() }) {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Files")
                }
            }
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Camera")
                }
            }
            .disabled(true)
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("Photo Library")
                }
            }
            .disabled(true)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.white)
        }
    }
    
    private var microphoneButton: some View {
        Button(action: {
            if speechManager.isRecording {
                speechManager.stopRecording()
            } else {
                speechManager.startRecording()
            }
        }) {
            Image(systemName: speechManager.isRecording ? "stop.fill" : "waveform.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .disabled(!speechManager.isSpeechRecognitionAvailable)
    }
    
    private var sendButton: some View {
        Button(action: {
            HapticManager.impactOccurred(style: .medium)
            if !cantSend {
                if speechManager.isRecording { speechManager.stopRecording() }
                prepareAndSendMessage()
            }
        }) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(cantSend ? Color(uiColor: .systemGray3) : Color.white)
        }
        .disabled(cantSend)
    }
    
    private var stopButton: some View {
        Button(action: {
            HapticManager.impactOccurred(style: .medium)
            chatManager.stopGeneratingResponse()
        }){
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.3 + animationPhase * 0.2),
                                Color.indigo.opacity(0.2 + animationPhase * 0.15),
                                Color.blue.opacity(0.25 + animationPhase * 0.1),
                                Color.purple.opacity(0.35 + animationPhase * 0.25)
                            ],
                            startPoint: UnitPoint(x: 0.2 + animationPhase * 0.6, y: 0.1),
                            endPoint: UnitPoint(x: 0.8 - animationPhase * 0.6, y: 0.9)
                        )
                    )
                    .opacity(0.8)
            )
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.0375 + animationPhase * 0.15),
                        Color.indigo.opacity(0.025 + animationPhase * 0.1),
                        Color.purple.opacity(0.025 + animationPhase * 0.125)
                    ],
                    startPoint: gradientStartPoint,
                    endPoint: gradientEndPoint
                ),
                lineWidth: 1.5
            )
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
            animationPhase = 1.0
        }
    }
    
    private func animateGradientPoints() async {
        do {
            while !Task.isCancelled {
                let newStartPoint = UnitPoint(x: Double.random(in: 0...1), y: Double.random(in: 0...1))
                let newEndPoint = UnitPoint(x: Double.random(in: 0...1), y: Double.random(in: 0...1))
                
                withAnimation(.easeInOut(duration: 2.0)) {
                    gradientStartPoint = newStartPoint
                    gradientEndPoint = newEndPoint
                }
                try await Task.sleep(for: .seconds(2.5))
            }
        } catch {}
    }
    
    private func prepareAndSendMessage() {
        guard !cantSend else { return }
        if speechManager.isRecording { speechManager.stopRecording() }
        onSend(text)
    }
}

#Preview {
    Main()
        .preferredColorScheme(.dark)
}
