#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN="$1"
mkdir -p certs

openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "certs/${DOMAIN}.key" \
  -out "certs/${DOMAIN}.crt" \
  -days 365 \
  -subj "/CN=${DOMAIN}"

echo "Generated certs/${DOMAIN}.crt and certs/${DOMAIN}.key"
echo "For production webhook, use a CA-trusted cert (Let's Encrypt or Cloudflare Origin Cert with Cloudflare proxy)."
