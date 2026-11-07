#!/bin/zsh
# Creates a self-signed code-signing certificate in your login keychain, so every build is
# signed with the same identity. macOS then keeps privacy permissions (Accessibility) across
# rebuilds. This is NOT an Apple Developer ID: other Macs still need the one-time
# "Open Anyway" approval. Run once per machine.
set -euo pipefail

NAME="Trackpad Expression Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Certificate \"$NAME\" already exists."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# LibreSSL (/usr/bin/openssl) writes a PKCS#12 format the macOS keychain imports reliably.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$NAME" -passout pass:tpex -out "$TMP/id.p12"

security import "$TMP/id.p12" -k "$KEYCHAIN" -P tpex -T /usr/bin/codesign >/dev/null
echo "Imported \"$NAME\" into the login keychain."
echo "The first signing may ask to let codesign use the key — choose \"Always Allow\"."
