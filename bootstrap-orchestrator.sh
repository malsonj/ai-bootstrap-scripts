#!/usr/bin/env bash
set -euo pipefail

INFRA_REPO_URL="${INFRA_REPO_URL:-git@github.com-ai-infrastructure:malsonj/ai-infrastructure.git}"
INFRA_REF="${INFRA_REF:-main}"
INFRA_DIR="${INFRA_DIR:-/opt/ai-infrastructure}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
BOOTSTRAP_SSH_KEY_PATH="${BOOTSTRAP_SSH_KEY_PATH:-/home/agent/.ssh/id_bootstrap}"
BOOTSTRAP_SSH_KNOWN_HOSTS_PATH="${BOOTSTRAP_SSH_KNOWN_HOSTS_PATH:-/home/agent/.ssh/known_hosts}"
DNS_WAIT_HOST="${DNS_WAIT_HOST:-github.com}"
DNS_WAIT_ATTEMPTS="${DNS_WAIT_ATTEMPTS:-30}"
DNS_WAIT_DELAY_SECONDS="${DNS_WAIT_DELAY_SECONDS:-2}"
GIT_RETRY_ATTEMPTS="${GIT_RETRY_ATTEMPTS:-5}"
GIT_RETRY_DELAY_SECONDS="${GIT_RETRY_DELAY_SECONDS:-3}"

wait_for_dns() {
    local host="${1:-$DNS_WAIT_HOST}"
    local attempts="${2:-$DNS_WAIT_ATTEMPTS}"
    local delay="${3:-$DNS_WAIT_DELAY_SECONDS}"
    local i

    for ((i=1; i<=attempts; i++)); do
        if getent hosts "$host" >/dev/null 2>&1; then
            echo "[BOOTSTRAP] DNS ready for $host"
            return 0
        fi
        echo "[BOOTSTRAP] Waiting for DNS for $host ($i/$attempts)..."
        sleep "$delay"
    done

    echo "[BOOTSTRAP] DNS did not resolve $host after $attempts attempts." >&2
    return 1
}

retry_command() {
    local attempts="$1"
    local delay="$2"
    shift 2
    local i

    for ((i=1; i<=attempts; i++)); do
        if "$@"; then
            return 0
        fi
        if [ "$i" -lt "$attempts" ]; then
            echo "[BOOTSTRAP] Command failed, retrying ($i/$attempts): $*"
            sleep "$delay"
        fi
    done

    echo "[BOOTSTRAP] Command failed after $attempts attempts: $*" >&2
    return 1
}

clone_url="$INFRA_REPO_URL"
git_ssh_command=""
if [ -f "$BOOTSTRAP_SSH_KEY_PATH" ] && [[ "$INFRA_REPO_URL" =~ ^https://github\.com/([^/]+)/([^/]+)\.git$ ]]; then
    clone_url="git@github.com:${BASH_REMATCH[1]}/${BASH_REMATCH[2]}.git"
    git_ssh_command="ssh -i $BOOTSTRAP_SSH_KEY_PATH -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$BOOTSTRAP_SSH_KNOWN_HOSTS_PATH"
elif [ -n "$GITHUB_TOKEN" ] && [[ "$INFRA_REPO_URL" =~ ^https://github\.com/ ]]; then
    clone_url="${INFRA_REPO_URL/https:\/\/github.com\//https:\/\/x-access-token:${GITHUB_TOKEN}@github.com/}"
fi

echo "[BOOTSTRAP] Fetching infrastructure repo..."
wait_for_dns "$DNS_WAIT_HOST"

if [ ! -d "$INFRA_DIR/.git" ]; then
    rm -rf "$INFRA_DIR"
    if [ -n "$git_ssh_command" ]; then
        retry_command "$GIT_RETRY_ATTEMPTS" "$GIT_RETRY_DELAY_SECONDS" \
            env GIT_SSH_COMMAND="$git_ssh_command" git clone "$clone_url" "$INFRA_DIR"
    else
        retry_command "$GIT_RETRY_ATTEMPTS" "$GIT_RETRY_DELAY_SECONDS" \
            git clone "$clone_url" "$INFRA_DIR"
    fi
else
    if [ -n "$git_ssh_command" ]; then
        retry_command "$GIT_RETRY_ATTEMPTS" "$GIT_RETRY_DELAY_SECONDS" \
            env GIT_SSH_COMMAND="$git_ssh_command" git -C "$INFRA_DIR" fetch --all --tags --prune
    else
        retry_command "$GIT_RETRY_ATTEMPTS" "$GIT_RETRY_DELAY_SECONDS" \
            git -C "$INFRA_DIR" fetch --all --tags --prune
    fi
fi
git -C "$INFRA_DIR" checkout "$INFRA_REF"
if [ -n "$git_ssh_command" ]; then
    retry_command "$GIT_RETRY_ATTEMPTS" "$GIT_RETRY_DELAY_SECONDS" \
        env GIT_SSH_COMMAND="$git_ssh_command" git -C "$INFRA_DIR" pull --ff-only origin "$INFRA_REF" || true
else
    retry_command "$GIT_RETRY_ATTEMPTS" "$GIT_RETRY_DELAY_SECONDS" \
        git -C "$INFRA_DIR" pull --ff-only origin "$INFRA_REF" || true
fi

echo "[BOOTSTRAP] Running orchestrator-node bootstrap..."
bash "$INFRA_DIR/scripts/bootstrap-orchestrator.sh"
