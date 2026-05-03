#!/usr/bin/env bash
# Extracts public domain names from the SOPS-encrypted newt blueprint.
# Only domain names (public DNS records) are output -- no sensitive data.
set -euo pipefail

SITES_PATH="${1:?Usage: extract-domains.sh <sites.yaml path>}"

sops -d "$SITES_PATH" \
  | awk '/^---/{doc++} doc==1' \
  | yq '.stringData."blueprint.yaml"' \
  | yq -o=json '[.public-resources[].full-domain]' \
  | jq '{domains: ([.[]] | join(","))}'