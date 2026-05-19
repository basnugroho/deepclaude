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

# Create .env template if not exists
ENV_KEYS_FILE="$HOME/.deepclaude-keys"
if [ ! -f "$ENV_KEYS_FILE" ]; then
    cat > "$ENV_KEYS_FILE" << 'EOF'
# DeepClaude API Keys
# Edit this file with your actual API keys

DEEPSEEK_API_KEY=sk-your-deepseek-key-here
# OPENROUTER_API_KEY=sk-or-your-key-here
# FIREWORKS_API_KEY=your-key-here
EOF
    echo "[OK] Created $ENV_KEYS_FILE - edit with your API keys"
else
    echo "[OK] $ENV_KEYS_FILE already exists"
fi

# Add .env loading to .bashrc if not present
if ! grep -q "deepclaude-keys" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# Load DeepClaude API keys
if [ -f "$HOME/.deepclaude-keys" ]; then
    set -a
    source "$HOME/.deepclaude-keys"
    set +a
fi
EOF
    echo "[OK] Added .env loading to $BASHRC"
fi

echo ""
echo "========================================"
echo "Setup complete!"
echo "========================================"
echo ""
echo "1. Edit ~/.deepclaude-keys with your API keys:"
echo "   nano ~/.deepclaude-keys"
echo ""
echo "2. Reload: source ~/.bashrc"
echo ""
echo "3. Start proxy: start-deepclaude"
echo ""
echo "To switch modes (then restart VSCode SSH):"
echo "  switch-deepseek   # Use DeepSeek via proxy"
echo "  switch-anthropic  # Use Anthropic directly"
echo ""
