#!/bin/bash
# Compila Dicta y ensambla el bundle build/Dicta.app
# Uso: ./build.sh [debug|release] [install]
#
# Notas de esta máquina:
# - Compila con swiftc directamente (el SwiftPM de los Command Line Tools está
#   roto por una actualización parcial) y con el SDK 15.5 explícito (el
#   compilador Swift 6.1.2 no soporta el SDK 26.2 instalado).
# - whisper.cpp se clona y compila en vendor/ la primera vez (estático + Metal;
#   GGML_METAL_EMBED_LIBRARY evita depender del compilador de Metal de Xcode).
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="build/Dicta.app"

SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk"
if [ ! -d "$SDK" ]; then
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi

CMAKE="$(command -v cmake || echo /opt/homebrew/bin/cmake)"
VENDOR="vendor/whisper.cpp"
WBUILD="$VENDOR/build-static"

if [ ! -f "$WBUILD/src/libwhisper.a" ]; then
  echo "→ Compilando whisper.cpp (primera vez)…"
  if [ ! -d "$VENDOR" ]; then
    git clone --depth 1 --branch v1.7.4 https://github.com/ggerganov/whisper.cpp "$VENDOR"
  fi
  "$CMAKE" -S "$VENDOR" -B "$WBUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF \
    -DCMAKE_OSX_SYSROOT="$SDK" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 > /dev/null
  "$CMAKE" --build "$WBUILD" -j "$(sysctl -n hw.ncpu)"
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
  -I Support/CWhisper \
  -I "$VENDOR/include" \
  -I "$VENDOR/ggml/include" \
  -L "$WBUILD/src" \
  -L "$WBUILD/ggml/src" \
  -L "$WBUILD/ggml/src/ggml-metal" \
  -L "$WBUILD/ggml/src/ggml-blas" \
  -lwhisper -lggml -lggml-base -lggml-cpu -lggml-metal -lggml-blas \
  -lc++ \
  -framework Metal \
  -framework Foundation \
  -framework Accelerate \
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
