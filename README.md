# Dicta

Dictado por voz para macOS. Vive en la barra de menús: mantienes presionada
una tecla, hablas, la sueltas — y el texto se escribe donde esté tu cursor,
en cualquier app (Slack, correo, navegador, editores).

**Descarga:** https://github.com/aaronxmrquez/speech-app/releases/latest/download/Dicta.dmg

Requisitos: Mac con Apple Silicon (M1+) y macOS 14+. La app no está
notarizada: la primera apertura pide "Abrir de todos modos" en Ajustes del
Sistema → Privacidad y seguridad.

## Uso

- **Mantener tecla** (por defecto ⌘ derecha; cambiable a ⌥ derecha o fn):
  mantén, habla, suelta. **Esc** cancela. Los atajos normales (⌘C…) siguen
  funcionando mientras dictas.
- **Alternar**: ⌥ Espacio inicia/detiene (elegible en Settings).
- **Idioma**: Auto (detección automática es/en con Whisper), Español o English.
- **History**: los últimos 100 dictados, clic para copiar. Local siempre.
- La UI de la app está en inglés; branding: carbón + Space Mono + Inter con
  acento verde, splash de bienvenida en la primera instalación.

## Motores

- **Whisper (por defecto)**: whisper.cpp + Metal, modelo large-v3-turbo
  cuantizado (574 MB, se descarga desde Settings una sola vez). Máxima
  precisión en español e inglés, 100 % local. Híbrido: parciales en vivo con
  el motor de Apple, texto final de Whisper (~1 s).
- **Apple**: SFSpeechRecognizer. Sin descargas, más liviano.

## Build

```sh
./build.sh release            # compila y ensambla build/Dicta.app
./build.sh release install    # además instala en /Applications
./build.sh release dmg        # genera build/Dicta.dmg distribuible
```

Notas de esta máquina: compila con `swiftc` directo contra el SDK de macOS
15.5 (el SwiftPM de los CLT está roto — ver comentario en `build.sh`).
whisper.cpp se clona y compila solo en `vendor/` la primera vez. La firma usa
el certificado local "Dicta Local Signing" si existe
(`Support/make_signing_cert.sh`); sin él cae a ad-hoc.

Assets de marca en `Support/`: logo, ícono de app y de barra de menús
(`make_icon.swift` los regenera), patrón del splash (SVG de Figma) y fuentes
Space Mono/Inter embebidas (OFL).

## Arquitectura

`HotkeyMonitor` (CGEventTap) → `AppState` (idle → grabando → transcribiendo →
insertando) → `AudioRecorder` (AVAudioEngine) alimenta al motor activo →
HUD flotante (`NSPanel` no activante) con parciales en vivo → `TextInserter`
(portapapeles + ⌘V sintético + restauración).

Los motores implementan el protocolo `TranscriptionEngine`
(Sources/Dicta/Transcription/): agregar uno nuevo no toca el resto.

Modos de desarrollo: `--render-previews <dir>` (renderiza las vistas a PNG),
`--transcribe-file <audio> [es|en|auto]` (prueba el motor sin micrófono),
`--splash` (muestra el splash de bienvenida).
