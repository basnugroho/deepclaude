#!/usr/bin/env bash
# fix-connection-linux.sh - Stop dan disable semua DeepClaude proxy di Linux
# Handles systemd services, background processes, dan env vars

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  DeepClaude Linux Cleanup"
echo "========================================"
echo ""

# 1. Check dan stop systemd service
echo "[1] Checking systemd services..."
if systemctl list-units --all | grep -q "deepclaude-proxy"; then
    echo "  ⚠ Found deepclaude-proxy.service"

    if systemctl is-active --quiet deepclaude-proxy 2>/dev/null; then
        echo "    Stopping service..."
        sudo systemctl stop deepclaude-proxy
        echo "    ✓ Service stopped"
    fi

    if systemctl is-enabled --quiet deepclaude-proxy 2>/dev/null; then
        echo "    Disabling auto-start..."
        sudo systemctl disable deepclaude-proxy
        echo "    ✓ Auto-start disabled"
    fi

    echo "  Service status:"
    systemctl status deepclaude-proxy --no-pager || true
else
    echo "  ✓ No systemd service found"
fi

# 2. Kill all Node.js processes
echo ""
echo "[2] Stopping Node.js processes..."
NODE_PIDS=$(pgrep -f "node.*proxy" || true)
if [[ -n "$NODE_PIDS" ]]; then
    echo "  Found processes: $NODE_PIDS"
    kill -9 $NODE_PIDS 2>/dev/null || true
    echo "  ✓ Killed Node.js proxy processes"
else
    echo "  ✓ No Node.js processes found"
fi

# 3. Free port 3200
echo ""
echo "[3] Freeing port 3200..."
PORT_PID=$(lsof -ti:3200 || true)
if [[ -n "$PORT_PID" ]]; then
    echo "  Found process on port 3200: PID $PORT_PID"
    kill -9 $PORT_PID 2>/dev/null || true
    echo "  ✓ Port 3200 freed"
else
    echo "  ✓ Port 3200 is free"
fi

# 4. Check PM2 processes
echo ""
echo "[4] Checking PM2 processes..."
if command -v pm2 &> /dev/null; then
    PM2_PROXY=$(pm2 list | grep -i "proxy\|deepclaude" || true)
    if [[ -n "$PM2_PROXY" ]]; then
        echo "  ⚠ Found PM2 processes:"
        pm2 list | grep -i "proxy\|deepclaude" || true
        echo ""
        read -p "  Delete PM2 processes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pm2 delete all
            pm2 save --force
            echo "  ✓ PM2 processes deleted"
        fi
    else
        echo "  ✓ No PM2 proxy processes"
    fi
else
    echo "  ℹ PM2 not installed (OK)"
fi

# 5. Check cron jobs
echo ""
echo "[5] Checking cron jobs..."
CRON_PROXY=$(crontab -l 2>/dev/null | grep -i "proxy\|deepclaude" || true)
if [[ -n "$CRON_PROXY" ]]; then
    echo "  ⚠ Found cron jobs:"
    echo "$CRON_PROXY"
    echo ""
    echo "  Please manually remove from: crontab -e"
else
    echo "  ✓ No cron jobs found"
fi

# 6. Clean shell profiles
echo ""
echo "[6] Cleaning shell profiles..."
PROFILES=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
    "$HOME/.bash_profile"
)

for profile in "${PROFILES[@]}"; do
    if [[ -f "$profile" ]]; then
        if grep -q "ANTHROPIC_BASE_URL\|DEEPSEEK_API_KEY\|127.0.0.1:3200" "$profile" 2>/dev/null; then
            echo "  ⚠ Found proxy settings in: $profile"
            cp "$profile" "$profile.backup.$(date +%Y%m%d-%H%M%S)"
            sed -i.bak '/ANTHROPIC_BASE_URL/d; /DEEPSEEK_API_KEY/d; /OPENROUTER_API_KEY/d; /FIREWORKS_API_KEY/d' "$profile" 2>/dev/null || true
            echo "    ✓ Cleaned (backup saved)"
        fi
    fi
done

# 7. Unset current session env vars
echo ""
echo "[7] Unsetting environment variables..."
unset ANTHROPIC_BASE_URL 2>/dev/null || true
unset ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
unset DEEPSEEK_API_KEY 2>/dev/null || true
unset OPENROUTER_API_KEY 2>/dev/null || true
unset FIREWORKS_API_KEY 2>/dev/null || true
unset ANTHROPIC_DEFAULT_OPUS_MODEL 2>/dev/null || true
unset ANTHROPIC_DEFAULT_SONNET_MODEL 2>/dev/null || true
unset ANTHROPIC_DEFAULT_HAIKU_MODEL 2>/dev/null || true
unset CLAUDE_CODE_SUBAGENT_MODEL 2>/dev/null || true
echo "  ✓ Environment variables unset"

# 8. Disable .env file
echo ""
echo "[8] Checking .env file..."
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    mv "$ENV_FILE" "$SCRIPT_DIR/.env.disabled.$TIMESTAMP"
    echo "  ✓ Renamed .env to .env.disabled.$TIMESTAMP"
else
    echo "  ✓ No .env file found"
fi

# 9. Remove slash commands
echo ""
echo "[9] Checking Claude slash commands..."
COMMANDS_DIR="$HOME/.claude/commands"
if [[ -d "$COMMANDS_DIR" ]]; then
    SLASH_CMDS=$(find "$COMMANDS_DIR" -name "deepseek.md" -o -name "anthropic.md" -o -name "openrouter.md" 2>/dev/null || true)
    if [[ -n "$SLASH_CMDS" ]]; then
        echo "  ⚠ Found slash commands:"
        echo "$SLASH_CMDS"
        echo ""
        read -p "  Delete slash commands? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$COMMANDS_DIR/deepseek.md" "$COMMANDS_DIR/anthropic.md" "$COMMANDS_DIR/openrouter.md"
            echo "  ✓ Slash commands deleted"
        fi
    else
        echo "  ✓ No slash commands found"
    fi
else
    echo "  ℹ Commands directory not found (OK)"
fi

# 10. Verification
echo ""
echo "[10] Final verification..."

# Check if anything still listening on 3200
if lsof -i:3200 &>/dev/null; then
    echo "  ⚠ WARNING: Port 3200 still in use!"
    lsof -i:3200
else
    echo "  ✓ Port 3200 is free"
fi

# Check if node processes still running
if pgrep -f "node.*proxy" &>/dev/null; then
    echo "  ⚠ WARNING: Node proxy processes still running!"
    pgrep -af "node.*proxy"
else
    echo "  ✓ No Node proxy processes"
fi

# Check env vars
if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    echo "  ⚠ WARNING: ANTHROPIC_BASE_URL still set: $ANTHROPIC_BASE_URL"
else
    echo "  ✓ ANTHROPIC_BASE_URL is unset"
fi

# Summary
echo ""
echo "========================================"
echo "  Cleanup Complete!"
echo "========================================"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "  1. Close this terminal"
echo "  2. Open a NEW terminal (to reload shell profile)"
echo "  3. Verify: echo \$ANTHROPIC_BASE_URL"
echo "     (should be empty)"
echo "  4. Test: claude"
echo ""
echo "If still connecting to DeepSeek:"
echo "  - Logout and login: claude logout && claude login"
echo "  - Check systemd status: systemctl status deepclaude-proxy"
echo "  - Reboot server if needed: sudo reboot"
echo ""
echo "To restore DeepClaude later:"
echo "  - Rename .env.disabled.* back to .env"
echo "  - Run: ./deepclaude.sh"
echo ""
