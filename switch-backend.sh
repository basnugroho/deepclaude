#!/usr/bin/env bash
# switch-backend.sh - Simple one-command backend switcher
# Usage: ./switch-backend.sh [anthropic|deepseek|status]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_usage() {
    echo -e "${CYAN}Usage:${NC}"
    echo "  ./switch-backend.sh anthropic   # Switch to Anthropic (original Claude)"
    echo "  ./switch-backend.sh deepseek    # Switch to DeepSeek (cheap, no vision)"
    echo "  ./switch-backend.sh status      # Show current backend"
    echo ""
}

show_status() {
    echo -e "${CYAN}=== Current Backend Status ===${NC}"
    echo ""

    # Check systemd service
    if systemctl is-active --quiet deepclaude-proxy 2>/dev/null; then
        echo -e "  Systemd Service: ${GREEN}ACTIVE${NC}"
    else
        echo -e "  Systemd Service: ${YELLOW}INACTIVE${NC}"
    fi

    # Check port 3200
    if lsof -i:3200 &>/dev/null; then
        echo -e "  Port 3200:       ${GREEN}IN USE${NC} (proxy running)"
    else
        echo -e "  Port 3200:       ${YELLOW}FREE${NC}"
    fi

    # Check env var
    if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
        echo -e "  Env Variable:    ${GREEN}$ANTHROPIC_BASE_URL${NC}"
    else
        echo -e "  Env Variable:    ${YELLOW}Not set${NC}"
    fi

    # Determine current backend
    echo ""
    if systemctl is-active --quiet deepclaude-proxy 2>/dev/null && [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
        echo -e "  ${GREEN}Current Backend: DeepSeek (via proxy)${NC}"
        echo -e "  ${YELLOW}Note: Vision/image support disabled${NC}"
    elif [[ -z "${ANTHROPIC_BASE_URL:-}" ]]; then
        echo -e "  ${GREEN}Current Backend: Anthropic (original Claude)${NC}"
        echo -e "  ${YELLOW}Note: Full features including vision${NC}"
    else
        echo -e "  ${RED}Current Backend: Unknown/Mixed state${NC}"
    fi
    echo ""
}

switch_to_anthropic() {
    echo -e "${CYAN}=== Switching to Anthropic ===${NC}"
    echo ""

    # Stop and disable systemd service
    echo "  [1/5] Stopping proxy service..."
    if systemctl is-active --quiet deepclaude-proxy 2>/dev/null; then
        sudo systemctl stop deepclaude-proxy
        echo -e "    ${GREEN}✓${NC} Service stopped"
    else
        echo -e "    ${YELLOW}ℹ${NC} Service already stopped"
    fi

    echo "  [2/5] Disabling auto-start..."
    if systemctl is-enabled --quiet deepclaude-proxy 2>/dev/null; then
        sudo systemctl disable deepclaude-proxy
        echo -e "    ${GREEN}✓${NC} Auto-start disabled"
    else
        echo -e "    ${YELLOW}ℹ${NC} Already disabled"
    fi

    # Kill node processes
    echo "  [3/5] Stopping Node.js processes..."
    if pgrep -f "node.*proxy" &>/dev/null; then
        killall -9 node 2>/dev/null || true
        echo -e "    ${GREEN}✓${NC} Processes killed"
    else
        echo -e "    ${YELLOW}ℹ${NC} No processes found"
    fi

    # Free port 3200
    echo "  [4/5] Freeing port 3200..."
    if lsof -i:3200 &>/dev/null; then
        sudo lsof -ti:3200 | xargs -r sudo kill -9
        echo -e "    ${GREEN}✓${NC} Port freed"
    else
        echo -e "    ${YELLOW}ℹ${NC} Port already free"
    fi

    # Unset env vars
    echo "  [5/5] Clearing environment variables..."
    export ANTHROPIC_BASE_URL=""
    unset ANTHROPIC_BASE_URL 2>/dev/null || true
    echo -e "    ${GREEN}✓${NC} Variables cleared"

    echo ""
    echo -e "${GREEN}✓ Switched to Anthropic!${NC}"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo "  - Close this terminal and open a new one"
    echo "  - Or run: exec bash"
    echo "  - Then test: claude"
    echo ""
}

switch_to_deepseek() {
    echo -e "${CYAN}=== Switching to DeepSeek ===${NC}"
    echo ""

    # Check .env file
    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        # Check for disabled .env files
        DISABLED_ENV=$(ls -t "$SCRIPT_DIR/.env.disabled."* 2>/dev/null | head -1 || true)
        if [[ -n "$DISABLED_ENV" ]]; then
            echo -e "  ${YELLOW}Restoring .env from backup...${NC}"
            cp "$DISABLED_ENV" "$SCRIPT_DIR/.env"
            echo -e "    ${GREEN}✓${NC} .env restored"
        else
            echo -e "  ${RED}Error: No .env file found!${NC}"
            echo "  Please create .env with DEEPSEEK_API_KEY"
            echo "  Example: cp .env.example .env"
            exit 1
        fi
    fi

    # Source .env
    echo "  [1/5] Loading .env file..."
    set -a
    source "$SCRIPT_DIR/.env"
    set +a

    if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
        echo -e "    ${RED}✗${NC} DEEPSEEK_API_KEY not set in .env"
        exit 1
    fi
    echo -e "    ${GREEN}✓${NC} API key loaded"

    # Enable and start systemd service
    echo "  [2/5] Enabling systemd service..."
    if ! systemctl is-enabled --quiet deepclaude-proxy 2>/dev/null; then
        sudo systemctl enable deepclaude-proxy
        echo -e "    ${GREEN}✓${NC} Service enabled"
    else
        echo -e "    ${YELLOW}ℹ${NC} Already enabled"
    fi

    echo "  [3/5] Starting proxy service..."
    if ! systemctl is-active --quiet deepclaude-proxy 2>/dev/null; then
        sudo systemctl start deepclaude-proxy
        sleep 2  # Wait for service to start
        echo -e "    ${GREEN}✓${NC} Service started"
    else
        echo -e "    ${YELLOW}ℹ${NC} Already running"
    fi

    # Set env var
    echo "  [4/5] Setting environment variable..."
    export ANTHROPIC_BASE_URL="http://127.0.0.1:3200"
    echo -e "    ${GREEN}✓${NC} ANTHROPIC_BASE_URL set"

    # Verify
    echo "  [5/5] Verifying proxy..."
    sleep 1
    if curl -s http://127.0.0.1:3200/_proxy/status &>/dev/null; then
        echo -e "    ${GREEN}✓${NC} Proxy is responding"
    else
        echo -e "    ${RED}✗${NC} Proxy not responding"
        echo "    Check: sudo systemctl status deepclaude-proxy"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}✓ Switched to DeepSeek!${NC}"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo "  - Close this terminal and open a new one"
    echo "  - Or run: export ANTHROPIC_BASE_URL=http://127.0.0.1:3200"
    echo "  - Then test: claude"
    echo ""
    echo -e "${RED}Note: Vision/image support disabled with DeepSeek${NC}"
    echo ""
}

# Main
case "${1:-}" in
    anthropic)
        switch_to_anthropic
        ;;
    deepseek|ds)
        switch_to_deepseek
        ;;
    status)
        show_status
        ;;
    *)
        echo -e "${RED}Error: Invalid argument${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
