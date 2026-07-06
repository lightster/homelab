#!/usr/bin/env bash

set -euo pipefail

if [ -z "${ANSIBLE_VAULT_PASSWORD:-}" ]; then
  echo "ANSIBLE_VAULT_PASSWORD is required but not set" >&2
  exit 1
fi

printf '%s' "$ANSIBLE_VAULT_PASSWORD"
