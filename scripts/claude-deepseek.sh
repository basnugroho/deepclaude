#!/bin/bash
# Claude with DeepSeek via proxy
# Requires proxy to be running on port 3200

export ANTHROPIC_AUTH_TOKEN="unused"
export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
export ANTHROPIC_BASE_URL="http://127.0.0.1:3200"
export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"

# Check if proxy is running
if ! nc -z 127.0.0.1 3200 2>/dev/null; then
    echo "[WARN] Proxy not running on port 3200. Start with: start-deepclaude"
fi

exec claude "$@"
