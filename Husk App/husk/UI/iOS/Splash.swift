//
//  Splash.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//


import SwiftUI

struct Splash: View {
    
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var speechManager: SpeechToTextManager
    @EnvironmentObject var attachmentManager: AttachmentManager
    
    @AppStorage("onboarded") var onboarded: Bool = false
    
    var body: some View {
        if !onboarded {
            Onboarding()
        }else if chatManager.isLoading{
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                    
                    Spacer()
                }
            }
        }else{
            Main()
                .environmentObject(chatManager)
                .environmentObject(speechManager)
                .environmentObject(attachmentManager)
        }
    }
}
