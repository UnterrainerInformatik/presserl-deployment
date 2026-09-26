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

# Guard against a fork deploying with another site's site.env: the project name and the
# database directory must not belong to a deployment in a different directory.
here="$(pwd -P)"
owner_dir=$(docker ps -a --filter "label=com.docker.compose.project=${PRESSERL_ROUTER}" \
    --format '{{.Label "com.docker.compose.project.working_dir"}}' | sort -u | head -n 1)
if [ -n "$owner_dir" ] && [ "$owner_dir" != "$here" ]; then
    echo "Compose project '${PRESSERL_ROUTER}' is already deployed from $owner_dir, not $here." >&2
    echo "Set a unique PRESSERL_ROUTER (and PRESSERL_DB_DIR) in site.env." >&2
    exit 1
fi
for id in $(docker ps -aq); do
    project=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$id")
    [ "$project" = "${PRESSERL_ROUTER}" ] && continue
    if docker inspect --format '{{range .Mounts}}{{println .Source}}{{end}}' "$id" | grep -qxF "${PRESSERL_DB_DIR}"; then
        echo "PRESSERL_DB_DIR ${PRESSERL_DB_DIR} is already used by project '${project:-?}'." >&2
        echo "Set a unique PRESSERL_DB_DIR in site.env." >&2
        exit 1
    fi
done

if docker compose version >/dev/null 2>&1; then
    compose=(docker compose)
else
    compose=(docker-compose)
fi

"${compose[@]}" -f compose.yaml pull
"${compose[@]}" -f compose.yaml up -d --remove-orphans
