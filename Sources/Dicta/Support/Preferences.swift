import Foundation
import Combine

enum ActivationMode: String, CaseIterable, Identifiable {
    case hold
    case toggle
    var id: String { rawValue }
}

enum EngineKind: String, CaseIterable, Identifiable {
    case apple
    case whisper
    var id: String { rawValue }
}

enum HoldKey: String, CaseIterable, Identifiable {
    case rightCommand
    case rightOption
    case fn

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightCommand: return "⌘ derecha"
        case .rightOption: return "⌥ derecha"
        case .fn: return "fn 🌐"
        }
    }
}

struct DictationLanguage: Identifiable, Equatable {
    let id: String
    let label: String
    let short: String

    static let all: [DictationLanguage] = [
        .init(id: "auto", label: "Auto (detectar idioma)", short: "AUTO"),
        .init(id: "es-MX", label: "Español (Latinoamérica)", short: "ES"),
        .init(id: "es-ES", label: "Español (España)", short: "ES"),
        .init(id: "en-US", label: "English (US)", short: "EN"),
    ]

    static func by(id: String) -> DictationLanguage {
        all.first { $0.id == id } ?? all[0]
    }
}

@MainActor
final class Preferences: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var activationMode: ActivationMode {
        didSet { defaults.set(activationMode.rawValue, forKey: "activationMode") }
    }
    @Published var holdKey: HoldKey {
        didSet { defaults.set(holdKey.rawValue, forKey: "holdKey") }
    }
    @Published var languageId: String {
        didSet { defaults.set(languageId, forKey: "languageId") }
    }
    @Published var engine: EngineKind {
        didSet { defaults.set(engine.rawValue, forKey: "engine") }
    }
    @Published var playSounds: Bool {
        didSet { defaults.set(playSounds, forKey: "playSounds") }
    }
    @Published var saveHistory: Bool {
        didSet { defaults.set(saveHistory, forKey: "saveHistory") }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    var language: DictationLanguage { DictationLanguage.by(id: languageId) }

    init() {
        activationMode = ActivationMode(rawValue: defaults.string(forKey: "activationMode") ?? "") ?? .hold
        holdKey = HoldKey(rawValue: defaults.string(forKey: "holdKey") ?? "") ?? .rightCommand
        languageId = defaults.string(forKey: "languageId") ?? "es-MX"
        engine = EngineKind(rawValue: defaults.string(forKey: "engine") ?? "") ?? .whisper
        playSounds = defaults.object(forKey: "playSounds") == nil ? true : defaults.bool(forKey: "playSounds")
        saveHistory = defaults.object(forKey: "saveHistory") == nil ? true : defaults.bool(forKey: "saveHistory")
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
    }
}
