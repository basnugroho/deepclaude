#!/bin/bash
# Switch server to DeepSeek mode
# After running this, restart VSCode SSH session to apply

ENV_FILE="$HOME/.deepclaude-env"

cat > "$ENV_FILE" << 'EOF'
# DeepClaude Environment - DeepSeek Mode
export ANTHROPIC_AUTH_TOKEN="unused"
export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
export ANTHROPIC_BASE_URL="http://127.0.0.1:3200"
export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
EOF

echo "[OK] Switched to DeepSeek mode"
echo "[INFO] Restart VSCode SSH session to apply"

# Also apply to current session
source "$ENV_FILE"

# Check proxy status
if nc -z 127.0.0.1 3200 2>/dev/null; then
    echo "[OK] Proxy running on port 3200"
    curl -s http://127.0.0.1:3200/_proxy/status 2>/dev/null || true
else
    echo "[WARN] Proxy not running. Start with: start-deepclaude"
fi
