#!/usr/bin/env bash
set -euo pipefail

# Forward all args to the appropriate compose command
if docker compose version &>/dev/null; then
  exec docker compose "$@"
elif command -v docker-compose &>/dev/null; then
  exec docker-compose "$@"
else
  cat >&2 <<'EOF'
Error: neither 'docker compose' (Docker Compose v2 plugin) nor 'docker-compose' (legacy) was found on PATH.
Install Docker Compose or upgrade Docker so that 'docker compose' is available.
On many systems you can install the legacy tool with: sudo apt install docker-compose
EOF
  exit 1
fi
