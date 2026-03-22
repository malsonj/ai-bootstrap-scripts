#!/usr/bin/env bash
set -euo pipefail

INFRA_REPO_URL="${INFRA_REPO_URL:-https://github.com/malsonj/ai-infrastructure.git}"
INFRA_REF="${INFRA_REF:-main}"
INFRA_DIR="${INFRA_DIR:-/opt/ai-infrastructure}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

clone_url="$INFRA_REPO_URL"
if [ -n "$GITHUB_TOKEN" ] && [[ "$INFRA_REPO_URL" =~ ^https://github\.com/ ]]; then
    clone_url="${INFRA_REPO_URL/https:\/\/github.com\//https:\/\/x-access-token:${GITHUB_TOKEN}@github.com/}"
fi

echo "[BOOTSTRAP] Fetching infrastructure repo..."

if [ ! -d "$INFRA_DIR/.git" ]; then
    rm -rf "$INFRA_DIR"
    git clone "$clone_url" "$INFRA_DIR"
else
    git -C "$INFRA_DIR" fetch --all --tags --prune
fi
git -C "$INFRA_DIR" checkout "$INFRA_REF"
git -C "$INFRA_DIR" pull --ff-only origin "$INFRA_REF" || true

echo "[BOOTSTRAP] Running full-stack bootstrap..."
bash "$INFRA_DIR/scripts/bootstrap-full-stack.sh"
