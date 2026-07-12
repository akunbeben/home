#!/usr/bin/env bash
set -euo pipefail

identity_name="Privacy Mirror Local Code Signing"
keychain="$HOME/Library/Keychains/login.keychain-db"

existing_identity=$(/usr/bin/security find-identity -v -p codesigning "$keychain" \
  | /usr/bin/awk -v name="$identity_name" 'index($0, name) {print $2; exit}')

if [[ -n "$existing_identity" ]]; then
  echo "$identity_name already exists: $existing_identity"
  exit 0
fi

tmpdir=$(/usr/bin/mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

p12_password=$(/usr/bin/uuidgen)

cat >"$tmpdir/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $identity_name
[ ext ]
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = codeSigning
basicConstraints = critical,CA:true
subjectKeyIdentifier = hash
EOF

/usr/bin/openssl req \
  -x509 \
  -newkey rsa:2048 \
  -nodes \
  -days 3650 \
  -keyout "$tmpdir/key.pem" \
  -out "$tmpdir/cert.pem" \
  -config "$tmpdir/openssl.cnf" \
  >/dev/null 2>&1

/usr/bin/openssl pkcs12 \
  -export \
  -out "$tmpdir/cert.p12" \
  -inkey "$tmpdir/key.pem" \
  -in "$tmpdir/cert.pem" \
  -passout "pass:$p12_password" \
  >/dev/null 2>&1

/usr/bin/security import "$tmpdir/cert.p12" \
  -k "$keychain" \
  -P "$p12_password" \
  -A \
  -T /usr/bin/codesign \
  >/dev/null

/usr/bin/security add-trusted-cert \
  -r trustRoot \
  -k "$keychain" \
  "$tmpdir/cert.pem" \
  >/dev/null

identity=$(/usr/bin/security find-identity -v -p codesigning "$keychain" \
  | /usr/bin/awk -v name="$identity_name" 'index($0, name) {print $2; exit}')

if [[ -z "$identity" ]]; then
  echo "Failed to create $identity_name" >&2
  exit 1
fi

echo "Created $identity_name: $identity"
