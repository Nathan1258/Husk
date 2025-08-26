//
//  SpeechToTextManager.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//


import SwiftUI
import Speech
import AVFoundation

class SpeechToTextManager: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isSpeechRecognitionAvailable: Bool = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let preferredLocale = Locale.current

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: preferredLocale)

        updateSpeechRecognitionAvailability()
        requestAuthorization()
    }

    private func updateSpeechRecognitionAvailability() {
        guard let recognizer = speechRecognizer else {
            DispatchQueue.main.async {
                self.isSpeechRecognitionAvailable = false
                self.errorMessage = "Speech recognizer for locale \(self.preferredLocale.identifier) is not available."
            }
            return
        }

        let recognizerAvailable = recognizer.isAvailable
        let authStatus = SFSpeechRecognizer.authorizationStatus() == .authorized

        DispatchQueue.main.async {
            self.isSpeechRecognitionAvailable = recognizerAvailable && authStatus
            if !recognizerAvailable {
                self.errorMessage = "Speech recognizer is currently unavailable (e.g., no network for server-based recognition)."
            } else if !authStatus && SFSpeechRecognizer.authorizationStatus() != .notDetermined {
                self.errorMessage = "Speech recognition permission not granted."
            }
            if self.isSpeechRecognitionAvailable {
                if self.errorMessage == "Speech recognizer is currently unavailable (e.g., no network for server-based recognition)." ||
                   self.errorMessage == "Speech recognition permission not granted." {
                    self.errorMessage = nil
                }
            }
        }
    }

    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            self.updateSpeechRecognitionAvailability()

            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    break
                case .denied:
                    self.errorMessage = "Speech recognition authorization denied by user."
                case .restricted:
                    self.errorMessage = "Speech recognition restricted on this device."
                case .notDetermined:
                    self.errorMessage = "Speech recognition authorization not yet determined."
                @unknown default:
                    self.errorMessage = "Unknown speech recognition authorization status."
                }
            }
        }
    }

    func startRecording() {
        updateSpeechRecognitionAvailability()
        guard isSpeechRecognitionAvailable else {
            if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                requestAuthorization()
            }
            return
        }

        if audioEngine.isRunning {
            stopRecording()
            return
        }

        do {
            try startSpeechRecognitionSession()
            DispatchQueue.main.async {
                self.isRecording = true
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Recording setup failed: \(error.localizedDescription)"
                self.isRecording = false
            }
        }
    }

    private func startSpeechRecognitionSession() throws {
        guard let currentSpeechRecognizer = self.speechRecognizer, currentSpeechRecognizer.isAvailable else {
            throw NSError(domain: "SpeechToTextViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available."])
        }

        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object.")
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode

        recognitionTask = currentSpeechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                DispatchQueue.main.async {
                    self.isRecording = false
                    if let error {
                        if self.errorMessage == nil || self.errorMessage == "Listening..." {
                           self.errorMessage = "Speech recognition error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        DispatchQueue.main.async {
            self.transcribedText = "Listening..."
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
    }

    func refreshAvailability() {
        updateSpeechRecognitionAvailability()
    }
}
