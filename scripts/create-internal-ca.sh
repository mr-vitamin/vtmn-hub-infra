#!/bin/bash
# Initialize a NEW internal CA and wildcard/apex certificate.
# Not a renewal tool. Run from a trusted, user-controlled parent directory.
# Output: ./vtmn-ca/ (must not already exist, even as an empty directory/link).
# See docs/INTERNAL-CA.md before using this with real infrastructure.
set -Eeuo pipefail
umask 077

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [[ "$#" -eq 1 && "$1" == --help ]]; then
  printf '%s\n' \
    'Usage: bash create-internal-ca.sh' \
    'Initializes a new CA in ./vtmn-ca; refuses every existing output path.' \
    'This is NOT certificate renewal. Preserve the existing CA for renewal.'
  exit 0
fi
[[ "$#" -eq 0 ]] || fail 'No arguments accepted (except --help). Choose a trusted working directory.'

for tool in openssl mkdir cat; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required tool not found: $tool"
done

parent=$(pwd -P) || fail 'Cannot resolve the working directory.'
[[ -d "$parent" && -w "$parent" ]] || fail 'Working directory must exist and be writable.'
output="$parent/vtmn-ca"

# Atomic creation: unlike mkdir -p or an existence check, this also refuses
# empty directories, files, directory links, dangling links, and competing runs.
if ! mkdir -m 700 -- "$output"; then
  fail "Cannot create $output. It must be a new path. Do not delete or replace an existing CA to retry."
fi
cd -- "$output" || fail "Cannot enter $output. Output retained; inspect it manually before retrying."

stage='initialization'
trap 'status=$?; printf "ERROR: %s failed (exit %s). Partial output retained in %s. Do not rerun here or delete recovery material blindly.\n" "$stage" "$status" "$output" >&2; exit "$status"' ERR

stage='root private key generation'
openssl genrsa -out ca.key 4096
stage='root certificate generation'
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=US/O=VTMN Hub/CN=VTMN Hub Internal Root CA"

stage='server private key generation'
openssl genrsa -out vtmn-internal.key 2048
stage='server certificate request'
openssl req -new -key vtmn-internal.key -out vtmn-internal.csr \
  -subj "/C=US/O=VTMN Hub/CN=*.vtmn.internal"

stage='subject alternative name configuration'
cat > san.ext <<'EOF'
subjectAltName = DNS:*.vtmn.internal, DNS:vtmn.internal
EOF

# Preserve the original 825-day leaf validity; client acceptance is not assumed.
stage='server certificate signing'
openssl x509 -req -in vtmn-internal.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out vtmn-internal.crt -days 825 -sha256 -extfile san.ext

trap - ERR
printf 'Initialization completed in %s\n' "$output"
printf '%s\n' \
  'Keep ca.key private and protect a recovery copy before configuring services.' \
  'Only ca.crt belongs in client trust stores; never distribute the CA private key.' \
  'Verify the certificate chain, SANs, validity, permissions, and client compatibility before use.' \
  'For renewal, reuse the existing CA through a separately reviewed issuance procedure.'
