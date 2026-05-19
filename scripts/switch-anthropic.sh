#!/bin/bash
# Switch server to Anthropic mode (direct, no proxy)
# After running this, restart VSCode SSH session to apply

ENV_FILE="$HOME/.deepclaude-env"

cat > "$ENV_FILE" << 'EOF'
# DeepClaude Environment - Anthropic Mode (direct)
unset ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_DEFAULT_OPUS_MODEL
unset ANTHROPIC_DEFAULT_SONNET_MODEL
unset ANTHROPIC_DEFAULT_HAIKU_MODEL
unset ANTHROPIC_BASE_URL
unset CLAUDE_CODE_SUBAGENT_MODEL
EOF

echo "[OK] Switched to Anthropic mode (direct)"
echo "[INFO] Restart VSCode SSH session to apply"

# Also apply to current session
source "$ENV_FILE"
