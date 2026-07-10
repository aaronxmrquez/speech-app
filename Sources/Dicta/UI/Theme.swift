import SwiftUI
import AppKit

/// Sistema visual de Dicta (branding 2.0): carbón profundo, tipografía mono
/// en mayúsculas con tracking amplio, y verde eléctrico como único acento.
enum Theme {
    // Paleta
    static let background = Color(red: 0.102, green: 0.102, blue: 0.110) // #1A1A1C
    static let card = Color.white.opacity(0.045)
    static let cardBorder = Color.white.opacity(0.06)
    static let border = Color.white.opacity(0.10)
    static let divider = Color.white.opacity(0.07)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.32)
    static let accent = Color(red: 0.22, green: 0.84, blue: 0.06) // verde #38D610

    // Tipografía: Space Mono (embebida en Resources/Fonts) para titulares,
    // labels y controles; sans del sistema para descripciones.
    private static let spaceMonoAvailable = NSFont(name: "SpaceMono-Regular", size: 12) != nil

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        guard spaceMonoAvailable else {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        let boldWeights: Set<Font.Weight> = [.semibold, .bold, .heavy, .black]
        let name = boldWeights.contains(weight) ? "SpaceMono-Bold" : "SpaceMono-Regular"
        return .custom(name, size: size)
    }

    private static let interAvailable = NSFont(name: "Inter-Regular", size: 12) != nil

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard interAvailable else {
            return .system(size: size, weight: weight)
        }
        let boldWeights: Set<Font.Weight> = [.medium, .semibold, .bold, .heavy, .black]
        let name = boldWeights.contains(weight) ? "Inter-Medium" : "Inter-Regular"
        // Si la instancia Medium no existe en la fuente variable, cae a Regular.
        let resolved = NSFont(name: name, size: 12) != nil ? name : "Inter-Regular"
        return .custom(resolved, size: size)
    }
}
