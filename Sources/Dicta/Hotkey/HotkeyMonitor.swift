import AppKit
import CoreGraphics

/// Escucha el teclado a nivel de sistema con un CGEventTap (requiere Accesibilidad).
/// Detecta la tecla de mantener (flagsChanged), el atajo de alternar (⌥Espacio,
/// consumiéndolo para que no escriba nada) y Esc para cancelar.
final class HotkeyMonitor {
    /// Marca los eventos sintetizados por la propia app (p. ej. el ⌘V del TextInserter)
    /// para que el tap no los interprete como teclas del usuario.
    static let syntheticEventMarker: Int64 = 0xD1C7A

    enum Key {
        case rightCommand
        case rightOption
        case fn

        // Bits de modificador por dispositivo (NX_DEVICE…KEYMASK) para distinguir
        // la tecla derecha de la izquierda en eventos flagsChanged.
        var flagMask: UInt64 {
            switch self {
            case .rightCommand: return 0x0010 // NX_DEVICERCMDKEYMASK
            case .rightOption: return 0x0040  // NX_DEVICERALTKEYMASK
            case .fn: return CGEventFlags.maskSecondaryFn.rawValue
            }
        }

        var keyCode: Int64 {
            switch self {
            case .rightCommand: return 54
            case .rightOption: return 61
            case .fn: return 63
            }
        }
    }

    var holdKey: Key = .rightCommand
    var holdEnabled = true
    var toggleEnabled = false
    /// true mientras hay un dictado activo (lo actualiza AppState).
    var isCapturing = false

    var onHoldBegan: (() -> Void)?
    var onHoldEnded: (() -> Void)?
    var onToggle: (() -> Void)?
    var onCancel: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var holdKeyIsDown = false

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
        holdKeyIsDown = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS desactiva el tap si una callback tarda demasiado: re-activarlo.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .flagsChanged:
            guard holdEnabled,
                  event.getIntegerValueField(.keyboardEventKeycode) == holdKey.keyCode else { break }
            let down = event.flags.rawValue & holdKey.flagMask != 0
            if down && !holdKeyIsDown {
                holdKeyIsDown = true
                onHoldBegan?()
            } else if !down && holdKeyIsDown {
                holdKeyIsDown = false
                onHoldEnded?()
            }

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // ⌥Espacio: consumir el evento para que no inserte un espacio en la app activa.
            if toggleEnabled, keyCode == 49,
               event.flags.contains(.maskAlternate),
               !event.flags.contains(.maskCommand),
               !event.flags.contains(.maskControl),
               !event.flags.contains(.maskShift) {
                onToggle?()
                return nil
            }

            if isCapturing {
                if keyCode == 53 { // Esc: cancelar y consumir
                    onCancel?()
                    return nil
                }
                if holdKeyIsDown {
                    // Otra tecla mientras se mantiene la tecla de dictado: el usuario
                    // quería un atajo (p. ej. ⌘C) — cancelar y dejar pasar el evento.
                    onCancel?()
                }
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }
}
