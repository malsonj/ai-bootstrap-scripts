#!/usr/bin/env bash
set -euo pipefail

INFRA_REPO_URL="${INFRA_REPO_URL:-https://github.com/malsonj/ai-infrastructure.git}"
INFRA_DIR="${INFRA_DIR:-/opt/ai-infrastructure}"

echo "[BOOTSTRAP] Fetching infrastructure repo..."

if [ ! -d "$INFRA_DIR/.git" ]; then
    rm -rf "$INFRA_DIR"
    git clone "$INFRA_REPO_URL" "$INFRA_DIR"
else
    git -C "$INFRA_DIR" pull --ff-only
fi

echo "[BOOTSTRAP] Running full-stack bootstrap..."
bash "$INFRA_DIR/scripts/bootstrap-full-stack.sh"
