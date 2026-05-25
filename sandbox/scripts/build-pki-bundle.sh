#!/usr/bin/env bash
# Assemble the OpenShell PKI bundle YAML from a `generate-certs` output directory.
# Usage: build-pki-bundle.sh <generate-certs-output-dir> > openshell-pki.plain.yaml
set -euo pipefail
dir="${1:?usage: build-pki-bundle.sh <pki-dir>}"

emit() { # key file
  printf '%s: |\n' "$1"
  sed 's/^/  /' "$2"
}

emit ca_crt          "$dir/ca.crt"
emit server_tls_crt  "$dir/server/tls.crt"
emit server_tls_key  "$dir/server/tls.key"
emit client_tls_crt  "$dir/client/tls.crt"
emit client_tls_key  "$dir/client/tls.key"
emit jwt_signing_pem "$dir/jwt/signing.pem"
emit jwt_public_pem  "$dir/jwt/public.pem"
printf 'jwt_kid: "%s"\n' "$(tr -d '\n' < "$dir/jwt/kid")"
