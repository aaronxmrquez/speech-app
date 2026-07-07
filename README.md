# Dicta

Dictado por voz para macOS. Vive en la barra de menús: mantienes presionada
**⌘ derecha**, hablas, la sueltas — y el texto se escribe donde esté tu cursor,
en cualquier app (Slack, correo, navegador, editores). Diseño monocromo
negro/blanco.

## Uso

- **Mantener tecla** (por defecto): mantén ⌘ derecha y habla; al soltarla se
  inserta el texto. **Esc** cancela. Presionar cualquier otra tecla mientras
  mantienes también cancela (los atajos como ⌘C siguen funcionando).
- **Alternar**: ⌥ Espacio inicia y detiene (elegible en Ajustes).
- Idiomas: Auto (detección) / Español / English, cambiables desde el menú.

## Motores (v2)

- **Whisper (por defecto)**: whisper.cpp con Metal, modelo large-v3-turbo
  cuantizado (~574 MB, se descarga desde Ajustes la primera vez). Máxima
  precisión en español e inglés (incluso con acento) y detección automática
  de idioma. 100 % local. Híbrido: mientras hablas ves parciales en vivo del
  motor de Apple y al soltar se inserta el resultado de Whisper (~1 s).
  Mantiene el modelo en RAM (~800 MB) mientras la app corre.
- **Apple**: SFSpeechRecognizer. Más liviano, parciales en vivo, sin descargas.

Necesita tres permisos (el onboarding los guía): Micrófono, Reconocimiento de
voz y Accesibilidad.

## Build

```sh
./build.sh release            # compila y ensambla build/Dicta.app
./build.sh release install    # además instala en /Applications
```

Compila con `swiftc` directamente contra el SDK de macOS 15.5 (el SwiftPM de
los Command Line Tools de esta máquina está roto por una actualización parcial
— ver nota en build.sh). Firma ad-hoc: al recompilar, macOS puede pedir
re-conceder Accesibilidad.

El ícono se regenera con:

```sh
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk \
  -o /tmp/make_icon Support/make_icon.swift && /tmp/make_icon .
```

## Arquitectura

`HotkeyMonitor` (CGEventTap) → `AppState` (máquina de estados: idle → grabando
→ transcribiendo → insertando) → `AudioRecorder` (AVAudioEngine) alimenta a
`AppleSpeechEngine` (SFSpeechRecognizer, parciales en streaming) → HUD flotante
(`NSPanel` no activante) muestra waveform y texto en vivo → `TextInserter`
escribe el resultado (portapapeles + ⌘V sintético + restauración del
portapapeles original).

El motor de voz está detrás del protocolo `TranscriptionEngine`
(Sources/Dicta/Transcription/TranscriptionEngine.swift): para agregar Whisper
local o una API en la nube solo hay que implementar ese protocolo.

Modo de desarrollo: `Dicta --render-previews <dir>` renderiza las vistas
principales a PNG sin necesidad de permisos de grabación de pantalla.
