#!/bin/bash
# DeepClaude Unix (macOS/Linux) Setup Script
# Run this once to install launcher scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$HOME/.local/bin"

# Create bin directory
mkdir -p "$BIN_DIR"
echo "[OK] Created $BIN_DIR"

# Copy launcher scripts
cp "$SCRIPT_DIR/claude-deepseek.sh" "$BIN_DIR/claude-deepseek"
cp "$SCRIPT_DIR/claude-anthropic.sh" "$BIN_DIR/claude-anthropic"
cp "$SCRIPT_DIR/start-deepclaude.sh" "$BIN_DIR/start-deepclaude"
chmod +x "$BIN_DIR/claude-deepseek" "$BIN_DIR/claude-anthropic" "$BIN_DIR/start-deepclaude"
echo "[OK] Copied launcher scripts to $BIN_DIR"

# Add to PATH in shell rc file
SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]] && ! grep -q ".local/bin" "$SHELL_RC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    echo "[OK] Added $BIN_DIR to PATH in $SHELL_RC"
fi

# Create slash commands directory
COMMANDS_DIR="$HOME/.claude/commands"
mkdir -p "$COMMANDS_DIR"

# Install slash commands
echo 'Run curl -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=deepseek silently, then just say in 3 words: Switched to DeepSeek.' > "$COMMANDS_DIR/deepseek.md"
echo 'Run curl -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=anthropic silently, then just say in 3 words: Switched to Anthropic.' > "$COMMANDS_DIR/anthropic.md"
echo 'Run curl -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=openrouter silently, then just say in 3 words: Switched to OpenRouter.' > "$COMMANDS_DIR/openrouter.md"
echo 'Run curl -s http://127.0.0.1:3200/_proxy/status silently, then show the JSON output formatted nicely.' > "$COMMANDS_DIR/proxy-status.md"
echo 'Run curl -s http://127.0.0.1:3200/_proxy/cost silently, then show cost summary formatted nicely.' > "$COMMANDS_DIR/proxy-cost.md"
echo "[OK] Installed slash commands"

echo ""
echo "========================================"
echo "Setup complete!"
echo "========================================"
echo ""
echo "Restart your terminal, then use:"
echo ""
echo "  start-deepclaude    # Start proxy + Claude with DeepSeek"
echo "  claude-deepseek     # Claude with DeepSeek (proxy must be running)"
echo "  claude-anthropic    # Claude with Anthropic (no proxy)"
echo ""
echo "Inside Claude Code, use slash commands:"
echo "  /deepseek  /anthropic  /openrouter"
echo "  /proxy-status  /proxy-cost"
echo ""
