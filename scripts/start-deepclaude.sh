#!/bin/bash
# Start DeepClaude proxy (if not running) + Claude with DeepSeek

# Load API keys from .env file
if [ -f "$HOME/.deepclaude-keys" ]; then
    set -a
    source "$HOME/.deepclaude-keys"
    set +a
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROXY_SCRIPT="$REPO_DIR/proxy/start-proxy.js"

# Check if proxy script exists
if [[ ! -f "$PROXY_SCRIPT" ]]; then
    echo "[ERROR] Could not find proxy/start-proxy.js at $PROXY_SCRIPT"
    exit 1
fi

# Check if proxy is already running
if ! nc -z 127.0.0.1 3200 2>/dev/null; then
    echo "[INFO] Starting proxy on port 3200..."
    node "$PROXY_SCRIPT" --mode deepseek --port 3200 > /tmp/deepclaude-proxy.log 2>&1 &
    sleep 2

    if nc -z 127.0.0.1 3200 2>/dev/null; then
        echo "[OK] Proxy started on port 3200"
    else
        echo "[ERROR] Failed to start proxy. Check /tmp/deepclaude-proxy.log"
        exit 1
    fi
else
    echo "[OK] Proxy already running on port 3200"
fi

# Set DeepSeek env vars
export ANTHROPIC_AUTH_TOKEN="unused"
export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
export ANTHROPIC_BASE_URL="http://127.0.0.1:3200"
export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"

# Launch Claude
exec claude "$@"
