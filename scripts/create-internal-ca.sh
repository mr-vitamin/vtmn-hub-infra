#!/bin/bash
# Generates an internal root CA and a wildcard certificate for *.vtmn.internal.
# Run once (anywhere with openssl — doesn't need to be on the Proxmox host).
#
# Output:
#   ca.crt              - root CA cert. Import into every device's trust store
#                          (browsers/OS) that needs to access the platform over
#                          HTTPS without cert warnings.
#   ca.key               - root CA private key. NEVER commit or share this.
#   vtmn-internal.crt   - the actual server certificate for *.vtmn.internal
#   vtmn-internal.key    - its private key. NEVER commit or share this.
#
# vtmn-internal.crt + vtmn-internal.key get uploaded to Nginx Proxy Manager
# as a "Custom" SSL certificate, then attached to each proxy host with Force SSL on.

set -e
mkdir -p vtmn-ca
cd vtmn-ca

# Root CA (10 year validity)
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=US/O=VTMN Hub/CN=VTMN Hub Internal Root CA"

# Server cert with SAN covering the wildcard + apex domain (825 days, the
# max most browsers will accept for a leaf cert)
openssl genrsa -out vtmn-internal.key 2048
openssl req -new -key vtmn-internal.key -out vtmn-internal.csr \
  -subj "/C=US/O=VTMN Hub/CN=*.vtmn.internal"

cat > san.ext <<'EOF'
subjectAltName = DNS:*.vtmn.internal, DNS:vtmn.internal
EOF

openssl x509 -req -in vtmn-internal.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out vtmn-internal.crt -days 825 -sha256 -extfile san.ext

echo "Done. Files are in ./vtmn-ca/"
echo "Verify SAN: openssl x509 -in vtmn-internal.crt -noout -text | grep -A1 'Subject Alternative Name'"
