#!/bin/bash
# Crea un certificado local de firma de código ("Dicta Local Signing") en el
# llavero de sesión. Con identidad estable, el permiso de Accesibilidad
# sobrevive las recompilaciones (con firma ad-hoc se pierde en cada build).
#
# macOS mostrará UN diálogo pidiendo tu contraseña al confiar el certificado.
# Es una sola vez.
set -euo pipefail

CN="Dicta Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CN"; then
  echo "✓ El certificado '$CN' ya existe"
  exit 0
fi

DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$DIR/key.pem" -out "$DIR/cert.pem" \
  -subj "/CN=$CN" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:FALSE" 2>/dev/null

openssl pkcs12 -export -out "$DIR/dicta.p12" \
  -inkey "$DIR/key.pem" -in "$DIR/cert.pem" -passout pass:dicta-local

security import "$DIR/dicta.p12" -k "$KEYCHAIN" -P dicta-local -T /usr/bin/codesign

# Confiar el certificado para firma de código — aquí aparece el diálogo de contraseña.
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$DIR/cert.pem"

echo "✓ Certificado '$CN' creado y confiado"
