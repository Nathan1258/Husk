//
//  Settings.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//
import SwiftUI
import CloudKit

struct Settings: View {
    
    @AppStorage("isHapticFeedbackOn") private var isHapticFeedbackOn: Bool = true
    @AppStorage("shouldSyncWithiCloud") private var userSettingForiCloudSync: Bool = false
    @AppStorage("useLLMToCreateTitles") private var useLLMToCreateTitles: Bool = false
    
    @State private var showiCloudStatusAlert: Bool = false
    @State private var isProgrammaticallyUpdatingToggle: Bool = false

    
    @State private var currentAlertTitle: String = ""
    @State private var currentAlertMessage: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    private var iCloudSectionFooterText: String {
        if userSettingForiCloudSync {
            return "Your conversations will attempt to sync with iCloud on the next app launch. To stop syncing, toggle this off and restart the app."
        } else {
            return "Enable iCloud Sync to back up your conversations and access them across your devices. This requires an app restart to take effect."
        }
    }

    private var iCloudAlertTitle: String {
        if userSettingForiCloudSync {
            return "iCloud Sync Will Be Enabled"
        } else {
            return "iCloud Sync Will Be Disabled"
        }
    }

    private var iCloudAlertMessage: String {
        let restartMessage = "Please restart Husk for this change to take full effect."
        if userSettingForiCloudSync {
            return "On the next app launch, your conversations will begin syncing with your iCloud account. \(restartMessage)"
        } else {
            return "On the next app launch, conversations will no longer sync with iCloud and will be stored only on this device. \(restartMessage)"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: 20) {
                List{
                    Section("General"){
                        NavigationLink(destination: ConnectionsView()) {
                            HStack {
                                Image(systemName: "network")
                                    .foregroundColor(Color.primary)
                                Text("Connections")
                                Spacer()
                            }
                        }
                        
                        NavigationLink(destination: Personalisation()) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color.primary)
                                Text("Personalisation")
                                Spacer()
                            }
                        }
                    }
                    Section(
                        header: Text("App"),
                        footer: Text(iCloudSectionFooterText)
                    ){
                        Toggle(isOn: $isHapticFeedbackOn) {
                            HStack {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .foregroundColor(Color.primary)
                                Text("Haptic Feedback")
                            }
                        }.onChange(of: isHapticFeedbackOn){
                            HapticManager.selectionChanged()
                        }
                        
                        Toggle(isOn: $useLLMToCreateTitles) {
                            HStack {
                                Image(systemName: "newspaper.fill")
                                    .foregroundColor(Color.primary)
                                Text("Use LLM to create titles")
                            }
                        }.onChange(of: isHapticFeedbackOn){
                            HapticManager.selectionChanged()
                        }
                        
                        Toggle(isOn: $userSettingForiCloudSync) {
                            HStack {
                                Image(systemName: userSettingForiCloudSync ? "icloud.fill" : "icloud.slash.fill")
                                    .foregroundColor(userSettingForiCloudSync ? .blue : .gray)
                                Text("iCloud Sync")
                            }
                        }
                        .onChange(of: userSettingForiCloudSync) { oldValue, newValue in
                            HapticManager.selectionChanged()
                            if isProgrammaticallyUpdatingToggle {
                                isProgrammaticallyUpdatingToggle = false
                                return
                            }
                            
                            
                            if newValue == true {
                                checkiCloudAccountStatus { status in
                                    DispatchQueue.main.async {
                                        var shouldRevertToggle = false
                                        switch status {
                                        case .available:
                                            self.currentAlertTitle = "iCloud Sync Will Be Enabled"
                                            self.currentAlertMessage = "On the next app launch, your conversations will begin syncing with your iCloud account. Please restart Husk for this change to take full effect."
                                        case .noAccount:
                                            self.currentAlertTitle = "iCloud Account Needed"
                                            self.currentAlertMessage = "To enable iCloud Sync, please sign in to your iCloud account in the device Settings, then enable this setting again. An app restart will be required."
                                            shouldRevertToggle = true
                                        case .restricted:
                                            self.currentAlertTitle = "iCloud Restricted"
                                            self.currentAlertMessage = "Your iCloud account is restricted (e.g., parental controls). iCloud Sync cannot be enabled. Please check your device Settings."
                                            shouldRevertToggle = true
                                        case .couldNotDetermine:
                                            self.currentAlertTitle = "iCloud Status Unknown"
                                            self.currentAlertMessage = "Could not determine iCloud account status. Please check your internet connection and iCloud settings, then try again. An app restart will be required if you proceed."
                                            shouldRevertToggle = true
                                        case .temporarilyUnavailable:
                                            self.currentAlertTitle = "iCloud Temporarily Unavailable"
                                            self.currentAlertMessage = "iCloud is temporarily unavailable. Please try again later. An app restart will be required if you proceed."
                                            shouldRevertToggle = true
                                        @unknown default:
                                            self.currentAlertTitle = "iCloud Error"
                                            self.currentAlertMessage = "An unknown iCloud error occurred. Please check your iCloud settings. An app restart will be required if you proceed."
                                            shouldRevertToggle = true
                                        }
                                        if shouldRevertToggle {
                                            self.isProgrammaticallyUpdatingToggle = true
                                            self.userSettingForiCloudSync = false
                                        }
                                        self.showiCloudStatusAlert = true
                                    }
                                }
                            } else {
                                self.currentAlertTitle = "iCloud Sync Will Be Disabled"
                                self.currentAlertMessage = "On the next app launch, conversations will no longer sync with iCloud and will be stored only on this device. Please restart Husk for this change to take full effect."
                                self.showiCloudStatusAlert = true
                            }
                        }
                    }
                    
                    Section("About"){
                        
                        Button(action: {
                            if let url = URL(string: "mailto:husk-app@pm.me") {
                                UIApplication.shared.open(url)
                            }
                        }){
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(Color.primary)
                                Text("Help")
                                Spacer()
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .foregroundColor(Color.gray)
                            }
                        }
                        Button(action: {
                            if let url = URL(string: "https://github.com/Nathan1258/Husk") {
                                UIApplication.shared.open(url)
                            }
                        }){
                            HStack {
                                Image(systemName: "qrcode")
                                    .foregroundColor(Color.primary)
                                Text("Source Code")
                                Spacer()
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .foregroundColor(Color.gray)
                            }
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://github.com/Nathan1258/Husk") {
                                UIApplication.shared.open(url)
                            }
                        }){
                            HStack {
                                Image(systemName: "rectangle.3.group.fill")
                                    .foregroundColor(Color.primary)
                                Text("Acknowledgements")
                                Spacer()
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .foregroundColor(Color.gray)
                            }
                        }
                    }
            }
            .background(.clear)
            .scrollContentBackground(.hidden)
            .alert(currentAlertTitle, isPresented: $showiCloudStatusAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(currentAlertMessage)
            }
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.footnote)
                    .foregroundColor(Color.gray)
                    .padding(.top, 10)
                
            }
            .navigationTitle("Settings")
            .toolbar{
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.gray)
                            .padding(7)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Dismiss")
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
    
    private func checkiCloudAccountStatus(completion: @escaping (CKAccountStatus) -> Void) {
        CKContainer.default().accountStatus { status, error in
            if let error = error {
                print("Error checking iCloud account status: \(error.localizedDescription)")
                completion(.couldNotDetermine)
                return
            }
            completion(status)
        }
    }
}

struct ConnectionsView: View {
    
    
    @EnvironmentObject var chatManager: ChatManager
    
    @AppStorage("ollamaURL") var ollamaURL: String = "http://localhost"
    @AppStorage("ollamaPort") var ollamaPort: String = "11434"
    
    var body: some View {
        List {
            Section(
                header: Text("Ollama"),
                footer: Text("Enter the domain or IP address of the computer/server running your Ollama Instance. If you're not sure what port Ollama is running on, leave the default value.")
            ) {
                TextField("Enter server address (e.g., http://localhost)", text: $ollamaURL)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                
                TextField("Enter server port (default 11434)", text: $ollamaPort)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
            }
        }
        .navigationTitle("Connections")
        .hideKeyboardOnTap()
        .onDisappear(){
            Task{
                await chatManager.refreshModels()
            }
        }
    }

}

struct Personalisation: View {
    @AppStorage("userNameForPersonalisation") private var userName: String = ""
    @AppStorage("globalSystemPrompt") private var globalSystemPrompt: String = ""

    @FocusState private var isSystemPromptEditorFocused: Bool

    var body: some View {
        Form {
            Section(
                header: Text("Your Name"),
                footer: Text("Providing your name can help models address you personally. Your name is stored locally on your device and only included in prompts when interacting with models.")
            ) {
                TextField("Enter your name (optional)", text: $userName)
                    .autocorrectionDisabled(true)
                    .textContentType(.name)
            }

            Section(
                header: Text("Global System Prompt"),
                footer: Text("This system prompt will be prepended to the start of every new conversation to guide the model's behavior, tone, or persona. Leave blank for default behavior.")
            ) {
                TextEditor(text: $globalSystemPrompt)
                    .frame(minHeight: 100, maxHeight: 200)
                    .autocorrectionDisabled(true)
                    .focused($isSystemPromptEditorFocused)
                    .scrollContentBackground(.hidden)
                    .onTapGesture {
                        isSystemPromptEditorFocused = true
                    }


                if !globalSystemPrompt.isEmpty {
                    Button("Clear System Prompt", role: .destructive) {
                        globalSystemPrompt = ""
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Personalisation")
        .hideKeyboardOnTap()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isSystemPromptEditorFocused = false
                }
            }
        }
    }
}

