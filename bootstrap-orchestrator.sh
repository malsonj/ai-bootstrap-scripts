#!/usr/bin/env bash
set -euo pipefail

INFRA_REPO_URL="${INFRA_REPO_URL:-https://github.com/malsonj/ai-infrastructure.git}"
INFRA_REF="${INFRA_REF:-main}"
INFRA_DIR="${INFRA_DIR:-/opt/ai-infrastructure}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
BOOTSTRAP_SSH_KEY_PATH="${BOOTSTRAP_SSH_KEY_PATH:-/home/agent/.ssh/id_bootstrap}"
BOOTSTRAP_SSH_KNOWN_HOSTS_PATH="${BOOTSTRAP_SSH_KNOWN_HOSTS_PATH:-/home/agent/.ssh/known_hosts}"

clone_url="$INFRA_REPO_URL"
git_ssh_command=""
if [ -f "$BOOTSTRAP_SSH_KEY_PATH" ] && [[ "$INFRA_REPO_URL" =~ ^https://github\.com/([^/]+)/([^/]+)\.git$ ]]; then
    clone_url="git@github.com:${BASH_REMATCH[1]}/${BASH_REMATCH[2]}.git"
    git_ssh_command="ssh -i $BOOTSTRAP_SSH_KEY_PATH -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$BOOTSTRAP_SSH_KNOWN_HOSTS_PATH"
elif [ -n "$GITHUB_TOKEN" ] && [[ "$INFRA_REPO_URL" =~ ^https://github\.com/ ]]; then
    clone_url="${INFRA_REPO_URL/https:\/\/github.com\//https:\/\/x-access-token:${GITHUB_TOKEN}@github.com/}"
fi

echo "[BOOTSTRAP] Fetching infrastructure repo..."

if [ ! -d "$INFRA_DIR/.git" ]; then
    rm -rf "$INFRA_DIR"
    if [ -n "$git_ssh_command" ]; then
        GIT_SSH_COMMAND="$git_ssh_command" git clone "$clone_url" "$INFRA_DIR"
    else
        git clone "$clone_url" "$INFRA_DIR"
    fi
else
    if [ -n "$git_ssh_command" ]; then
        GIT_SSH_COMMAND="$git_ssh_command" git -C "$INFRA_DIR" fetch --all --tags --prune
    else
        git -C "$INFRA_DIR" fetch --all --tags --prune
    fi
fi
git -C "$INFRA_DIR" checkout "$INFRA_REF"
if [ -n "$git_ssh_command" ]; then
    GIT_SSH_COMMAND="$git_ssh_command" git -C "$INFRA_DIR" pull --ff-only origin "$INFRA_REF" || true
else
    git -C "$INFRA_DIR" pull --ff-only origin "$INFRA_REF" || true
fi

echo "[BOOTSTRAP] Running orchestrator-node bootstrap..."
bash "$INFRA_DIR/scripts/bootstrap-orchestrator.sh"
