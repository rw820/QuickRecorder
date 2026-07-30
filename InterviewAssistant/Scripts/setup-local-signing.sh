#!/bin/zsh
set -euo pipefail

identity_name="Interview Assistant Local Signing"
login_keychain="${HOME}/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning "${login_keychain}" \
  | grep -Fq "\"${identity_name}\""; then
  echo "${identity_name}"
  exit 0
fi

working_dir=$(mktemp -d)
trap 'rm -rf "${working_dir}"' EXIT
password=$(openssl rand -hex 24)

openssl req -new -newkey rsa:2048 -x509 -sha256 -days 3650 -nodes \
  -subj "/CN=${identity_name}/O=Local Development" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" \
  -keyout "${working_dir}/identity.key" \
  -out "${working_dir}/identity.crt"

openssl pkcs12 -export \
  -inkey "${working_dir}/identity.key" \
  -in "${working_dir}/identity.crt" \
  -out "${working_dir}/identity.p12" \
  -passout "pass:${password}"

security import "${working_dir}/identity.p12" \
  -k "${login_keychain}" \
  -P "${password}" \
  -T /usr/bin/codesign

security add-trusted-cert -d -r trustRoot -p codeSign \
  -k "${login_keychain}" \
  "${working_dir}/identity.crt"

echo "${identity_name}"
