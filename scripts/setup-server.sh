#!/bin/bash
# DeepClaude Server Setup
# Run this once on the remote server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$HOME/.local/bin"

echo "=== DeepClaude Server Setup ==="

# Create directories
mkdir -p "$BIN_DIR"
mkdir -p "$HOME/.claude/commands"

# Copy scripts
cp "$SCRIPT_DIR/switch-deepseek.sh" "$BIN_DIR/switch-deepseek"
cp "$SCRIPT_DIR/switch-anthropic.sh" "$BIN_DIR/switch-anthropic"
cp "$SCRIPT_DIR/start-deepclaude.sh" "$BIN_DIR/start-deepclaude"
chmod +x "$BIN_DIR/switch-deepseek" "$BIN_DIR/switch-anthropic" "$BIN_DIR/start-deepclaude"
echo "[OK] Installed scripts to $BIN_DIR"

# Setup .bashrc to source env file
BASHRC="$HOME/.bashrc"
ENV_FILE="$HOME/.deepclaude-env"

# Create default env file (DeepSeek mode)
cat > "$ENV_FILE" << 'EOF'
# DeepClaude Environment - DeepSeek Mode
export ANTHROPIC_AUTH_TOKEN="unused"
export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro"
export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
export ANTHROPIC_BASE_URL="http://127.0.0.1:3200"
export CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-flash"
EOF
echo "[OK] Created $ENV_FILE (default: DeepSeek mode)"

# Add source line to .bashrc if not present
if ! grep -q "deepclaude-env" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# DeepClaude environment
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.deepclaude-env" ] && source "$HOME/.deepclaude-env"
EOF
    echo "[OK] Added DeepClaude to $BASHRC"
else
    echo "[OK] DeepClaude already in $BASHRC"
fi

# Install slash commands
echo 'Run curl -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=deepseek silently, then just say: Switched to DeepSeek.' > "$HOME/.claude/commands/deepseek.md"
echo 'Run curl -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=anthropic silently, then just say: Switched to Anthropic.' > "$HOME/.claude/commands/anthropic.md"
echo 'Run curl -s http://127.0.0.1:3200/_proxy/status silently, then show the result.' > "$HOME/.claude/commands/proxy-status.md"
echo 'Run curl -s http://127.0.0.1:3200/_proxy/cost silently, then show cost summary.' > "$HOME/.claude/commands/proxy-cost.md"
echo "[OK] Installed slash commands"

# Remind about DEEPSEEK_API_KEY
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo ""
    echo "[WARN] DEEPSEEK_API_KEY not set. Add to ~/.bashrc:"
    echo "  export DEEPSEEK_API_KEY=\"sk-xxx\""
fi

echo ""
echo "========================================"
echo "Setup complete!"
echo "========================================"
echo ""
echo "1. Add DEEPSEEK_API_KEY to ~/.bashrc if not done"
echo "2. Run: source ~/.bashrc"
echo "3. Start proxy: start-deepclaude"
echo ""
echo "To switch modes (then restart VSCode SSH):"
echo "  switch-deepseek   # Use DeepSeek via proxy"
echo "  switch-anthropic  # Use Anthropic directly"
echo ""
