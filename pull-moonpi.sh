#!/usr/bin/env bash
set -euo pipefail
# pull-moonpi.sh
# Pulls the moonpi working directory from a remote Windows machine over SSH.
# Requires OpenSSH Server enabled on the Windows machine (Settings → Optional features).
# Usage:
#   ./pull-moonpi.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load personal defaults from .env if present (see .env.example)
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  source "$SCRIPT_DIR/.env"
fi

# Defaults — override these in .env
DEFAULT_REMOTE_USER="${DEFAULT_REMOTE_USER:-$USER}"
DEFAULT_REMOTE_HOST="${DEFAULT_REMOTE_HOST:-}"
DEFAULT_REMOTE_PATH="${DEFAULT_REMOTE_PATH:-}"
DEFAULT_LOCAL_PATH="${DEFAULT_LOCAL_PATH:-$HOME/MoonPi/moonpi}"

# Files/dirs to skip, relative to the root of the remote path
Excludes=(  )

# 1) Prompt for connection details
read -p "Remote user [${DEFAULT_REMOTE_USER}]: " REMOTE_USER
REMOTE_USER=${REMOTE_USER:-$DEFAULT_REMOTE_USER}

read -p "Remote host/IP [${DEFAULT_REMOTE_HOST}]: " REMOTE_HOST
REMOTE_HOST=${REMOTE_HOST:-$DEFAULT_REMOTE_HOST}

read -p "Remote path [${DEFAULT_REMOTE_PATH}]: " REMOTE_PATH
REMOTE_PATH=${REMOTE_PATH:-$DEFAULT_REMOTE_PATH}

read -p "Local path [${DEFAULT_LOCAL_PATH}]: " LOCAL_PATH
LOCAL_PATH=${LOCAL_PATH:-$DEFAULT_LOCAL_PATH}

[[ -z "$REMOTE_PATH" ]] && {
  echo "ERROR: Remote path must not be empty" >&2
  exit 1
}

# Ensure the local destination exists
mkdir -p "$LOCAL_PATH"

echo
echo "Pulling contents of ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH} → ${LOCAL_PATH}"

# 2) Build the remote tar command
remote_tar=( ssh "${REMOTE_USER}@${REMOTE_HOST}" \
  tar -C "${REMOTE_PATH}" -czf - )

for pat in "${Excludes[@]}"; do
  remote_tar+=( --exclude="${pat}" )
done

remote_tar+=( . )

# 3) Build the local unpack command
local_tar=( tar -C "${LOCAL_PATH}" -xzf - --warning=no-unknown-keyword )

# 4) Pipe remote→local
"${remote_tar[@]}" | "${local_tar[@]}"

echo "Done."
