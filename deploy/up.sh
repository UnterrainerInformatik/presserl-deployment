#!/usr/bin/env bash
# Called by the deploy workflow in the deploy directory on the server.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f secrets.env ]; then
    echo "secrets.env is missing in $(pwd); create it from README.md (Server secrets) first." >&2
    exit 1
fi

set -a
. ./.env
. ./site.env
. ./secrets.env
set +a

if docker compose version >/dev/null 2>&1; then
    compose=(docker compose)
else
    compose=(docker-compose)
fi

"${compose[@]}" -f compose.yaml pull
"${compose[@]}" -f compose.yaml up -d --remove-orphans
