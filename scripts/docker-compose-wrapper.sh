#!/usr/bin/env bash
set -e
# Use docker-compose if installed, otherwise fall back to `docker compose`
if command -v docker-compose >/dev/null 2>&1; then
  exec docker-compose "$@"
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  exec docker compose "$@"
else
  echo "Error: neither 'docker-compose' nor 'docker compose' is available." >&2
  exit 1
fi
