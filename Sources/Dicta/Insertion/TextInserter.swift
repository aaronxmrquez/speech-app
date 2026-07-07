import AppKit

/// Escribe texto en la app activa: lo pone en el portapapeles, simula ⌘V
/// y luego restaura el contenido anterior del portapapeles del usuario.
/// Funciona en apps nativas, Electron y navegadores por igual.
@MainActor
final class TextInserter {

    func insert(_ text: String, completion: @escaping () -> Void) {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Convención estándar para que los gestores de portapapeles ignoren esta entrada.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        // Pequeño margen para que se asiente el pasteboard y se suelten teclas físicas.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.postCommandV()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                self.restore(saved, to: pasteboard)
                completion()
            }
        }
    }

    // MARK: portapapeles

    private func snapshot(of pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var contents = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    contents[type] = data
                }
            }
            return contents
        }
    }

    private func restore(_ snapshot: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items = snapshot.map { contents -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    // MARK: teclado sintético

    private static func postCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        source.userData = HotkeyMonitor.syntheticEventMarker

        let keyV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
