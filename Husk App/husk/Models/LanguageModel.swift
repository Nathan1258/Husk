//
//  LanguageModel.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//
import Foundation
import OllamaKit

typealias Details = OKModelResponse.Model.ModelDetails

struct LanguageModel: Equatable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var provider: Provider
}
