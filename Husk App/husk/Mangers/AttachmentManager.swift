//
//  AttachmentManager.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//


import SwiftUI
import UniformTypeIdentifiers
import PDFKit

class AttachmentManager: ObservableObject {

    @Published var showFileImporter: Bool = false

    @Published var importedFileContent: String? = nil

    @Published var selectedFileName: String? = nil

    @Published var errorMessage: String? = nil

    let allowedContentTypes: [UTType] = [
        .plainText,
        .utf8PlainText,
        .text,
        .pdf,
        .commaSeparatedText,
        .json,
        .xml,            
        .swiftSource,
        .pythonScript,
    ]

    func selectFile() {
        self.importedFileContent = nil
        self.selectedFileName = nil
        self.errorMessage = nil
        self.showFileImporter = true
    }

    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let fileURLs):
            guard let fileURL = fileURLs.first else {
                self.errorMessage = "No file was selected. Please try again."
                print("Error: No file URL was provided.")
                return
            }
            guard fileURL.startAccessingSecurityScopedResource() else {
                self.errorMessage = "Unable to access the selected file. Please ensure you have the necessary permissions."
                print("Error: Could not start accessing security-scoped resource for \(fileURL.lastPathComponent).")
                return
            }

            defer {
                fileURL.stopAccessingSecurityScopedResource()
                print("Stopped accessing security-scoped resource for \(fileURL.lastPathComponent).")
            }

            self.selectedFileName = fileURL.lastPathComponent
            print("Selected file: \(self.selectedFileName ?? "Unknown") at \(fileURL.path)")
            extractStringContent(from: fileURL)

        case .failure(let error):
            self.errorMessage = "Failed to select file: \(error.localizedDescription)"
            print("Error picking file: \(error.localizedDescription)")
        }
    }

    private func extractStringContent(from url: URL) {
        do {
            let fileExtension = url.pathExtension.lowercased()
            var detectedUTType: UTType? = UTType(filenameExtension: fileExtension)

            if detectedUTType == nil {
                 if let typeIdentifier = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
                    detectedUTType = UTType(typeIdentifier)
                 }
            }
            
            print("Attempting to extract content from file with extension: \(fileExtension), detected UTType: \(detectedUTType?.identifier ?? "unknown")")

            if detectedUTType?.conforms(to: .text) == true {
                let content = try String(contentsOf: url, encoding: .utf8)
                self.importedFileContent = content
                self.errorMessage = nil
                print("Successfully extracted text content from \(url.lastPathComponent). Length: \(content.count) chars.")
            } else if detectedUTType?.conforms(to: .pdf) == true {
                if let pdfDocument = PDFDocument(url: url) {
                    if let content = pdfDocument.string {
                        self.importedFileContent = content
                        self.errorMessage = nil
                        print("Successfully extracted text from PDF: \(url.lastPathComponent). Length: \(content.count) chars.")
                    } else {
                        self.importedFileContent = ""
                        self.errorMessage = "Could not extract text from the PDF. It might be an image-based PDF, scanned, or empty."
                        print("PDF \(url.lastPathComponent) loaded, but no text content found.")
                    }
                } else {
                    self.errorMessage = "Failed to load the PDF document for text extraction."
                    print("Error: Could not initialize PDFDocument from URL: \(url.lastPathComponent).")
                }
            } else {
                self.errorMessage = "Unsupported file type for direct text extraction: '\(fileExtension)'. Please select a plain text file, PDF, or another supported document type."
                print("Unsupported file type for string extraction: \(url.lastPathComponent) (extension: \(fileExtension), UTType: \(detectedUTType?.identifier ?? "unknown")).")
            }
        } catch {
            self.errorMessage = "Error reading or processing file content: \(error.localizedDescription)"
            print("Error reading file content from \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    func clearAttachment() {
        self.importedFileContent = nil
        self.selectedFileName = nil
        self.errorMessage = nil
        self.showFileImporter = false
    }
}
