import SwiftUI

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

    // Tipografía: mono para titulares/labels/controles, sans para descripciones.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
