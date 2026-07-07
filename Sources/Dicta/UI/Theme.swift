import SwiftUI

/// Paleta monocroma de Dicta: negro profundo + blanco, sin color de acento.
enum Theme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04) // #0A0A0A
    static let card = Color.white.opacity(0.05)
    static let border = Color.white.opacity(0.10)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.5)
    static let tertiary = Color.white.opacity(0.3)
}
