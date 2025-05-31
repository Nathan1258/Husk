//
//  huskApp.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//

// huskApp.swift
import SwiftUI
import SwiftData

@main
struct huskApp: App {
    
    @StateObject private var chatManager: ChatManager
    @StateObject private var speechManager: SpeechToTextManager
    @StateObject private var attachmentManager: AttachmentManager
    
    @AppStorage("shouldSyncWithiCloud") private var userSettingForiCloudSync: Bool = false

    let modelContainer: ModelContainer
    let storeIdentifier = "HuskMainStore"

    init() {
        let schema = Schema([
            Conversation.self,
            ChatMessage.self,
        ])
        let useiCloudInitially = UserDefaults.standard.bool(forKey: "shouldSyncWithiCloud")
        
        let modelConfiguration: ModelConfiguration
        if useiCloudInitially {
            modelConfiguration = ModelConfiguration(
                storeIdentifier,
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.store.com.ellisn.husk")
            )
            print("SwiftData: Initializing ModelContainer with iCloud sync.")
        } else {
            modelConfiguration = ModelConfiguration(
                storeIdentifier,
                schema: schema,
                isStoredInMemoryOnly: false
            )
            print("SwiftData: Initializing ModelContainer for local-only storage.")
        }

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        let mainContext = self.modelContainer.mainContext
        let manager = ChatManager(modelContext: mainContext)
        _chatManager = StateObject(wrappedValue: manager)
        
        _speechManager = StateObject(wrappedValue: SpeechToTextManager())
        _attachmentManager = StateObject(wrappedValue: AttachmentManager())
    }

    var body: some Scene {
        WindowGroup {
            Splash()
                .environmentObject(chatManager)
                .environmentObject(speechManager)
                .environmentObject(attachmentManager)
        }
        .modelContainer(self.modelContainer)
    }
}
