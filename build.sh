#!/bin/bash
# Compila Dicta y ensambla el bundle build/Dicta.app
# Uso: ./build.sh [debug|release] [install]
#
# Nota: compila con swiftc directamente (los Command Line Tools de esta máquina
# tienen un SwiftPM roto por una actualización parcial). El SDK 15.5 se pasa
# explícito porque el compilador Swift 6.1.2 no soporta el SDK 26.2 instalado.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="build/Dicta.app"

SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk"
if [ ! -d "$SDK" ]; then
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi

OPT="-O"
if [ "$CONFIG" = "debug" ]; then
  OPT="-Onone -g"
fi

mkdir -p build
swiftc $OPT \
  -sdk "$SDK" \
  -target arm64-apple-macosx14.0 \
  -swift-version 5 \
  -parse-as-library \
  -o build/Dicta-bin \
  $(find Sources -name '*.swift')

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv build/Dicta-bin "$APP/Contents/MacOS/Dicta"
cp Support/Info.plist "$APP/Contents/Info.plist"
if [ -f Support/AppIcon.icns ]; then
  cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Firma ad-hoc: suficiente para uso local. Al recompilar, macOS puede pedir
# re-conceder el permiso de Accesibilidad (la identidad de código cambia).
codesign --force --sign - "$APP"

echo "✓ Bundle listo: $APP"

if [ "${2:-}" = "install" ]; then
  pkill -x Dicta 2>/dev/null || true
  sleep 0.5
  rm -rf /Applications/Dicta.app
  ditto "$APP" /Applications/Dicta.app
  # La firma ad-hoc cambia en cada build y deja obsoleto el permiso de
  # Accesibilidad (el switch se ve encendido pero no aplica). Resetearlo
  # para que el sistema lo pida de nuevo de forma honesta.
  tccutil reset Accessibility com.aaronmarquez.dicta >/dev/null 2>&1 || true
  echo "✓ Instalado en /Applications/Dicta.app"
  echo "  (recuerda re-conceder Accesibilidad si macOS lo pide)"
fi
