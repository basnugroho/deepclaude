#!/usr/bin/env bash
# deploy-linux.sh - Deploy DeepClaude updates to Linux server
# Usage: ./deploy-linux.sh [--systemd | --manual]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default mode
DEPLOY_MODE="systemd"
PROXY_PORT=3200

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --systemd) DEPLOY_MODE="systemd"; shift ;;
        --manual)  DEPLOY_MODE="manual"; shift ;;
        --port)    PROXY_PORT="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 [--systemd | --manual] [--port PORT]"
            echo ""
            echo "Options:"
            echo "  --systemd    Use systemd service (default, recommended for production)"
            echo "  --manual     Use manual background process (for testing)"
            echo "  --port PORT  Proxy port (default: 3200)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  DeepClaude Linux Deploy Script${NC}"
echo -e "${BLUE}  Mode: $DEPLOY_MODE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ================================
# Step 1: Check current status
# ================================
echo -e "${YELLOW}[1/7] Checking current status...${NC}"

# Check if proxy is running
PROXY_RUNNING=false
if curl -s --connect-timeout 2 http://127.0.0.1:$PROXY_PORT/_proxy/status > /dev/null 2>&1; then
    PROXY_RUNNING=true
    echo -e "  ${GREEN}✓${NC} Proxy is running on port $PROXY_PORT"
    curl -s http://127.0.0.1:$PROXY_PORT/_proxy/status | grep -E '"mode"|"uptime"|"requests"' | head -3
else
    echo -e "  ${YELLOW}⚠${NC} Proxy is not running"
fi

# Check systemd service
if [[ "$DEPLOY_MODE" == "systemd" ]]; then
    if systemctl is-active --quiet deepclaude-proxy 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} systemd service is active"
    else
        echo -e "  ${YELLOW}⚠${NC} systemd service is not active"
    fi
fi

# Check node processes
NODE_PROCS=$(pgrep -f "node.*start-proxy" || true)
if [[ -n "$NODE_PROCS" ]]; then
    echo -e "  ${GREEN}✓${NC} Found node processes: $NODE_PROCS"
else
    echo -e "  ${YELLOW}⚠${NC} No node processes found"
fi

echo ""

# ================================
# Step 2: Stop existing processes
# ================================
echo -e "${YELLOW}[2/7] Stopping existing processes...${NC}"

if [[ "$DEPLOY_MODE" == "systemd" ]]; then
    if systemctl is-active --quiet deepclaude-proxy 2>/dev/null; then
        echo -e "  Stopping systemd service..."
        sudo systemctl stop deepclaude-proxy
        echo -e "  ${GREEN}✓${NC} Service stopped"
    else
        echo -e "  ${YELLOW}⚠${NC} Service not running, skipping"
    fi
else
    # Manual mode: kill processes
    if [[ -n "$NODE_PROCS" ]]; then
        echo -e "  Killing node processes: $NODE_PROCS"
        pkill -f "node.*start-proxy" || true
        sleep 1
        echo -e "  ${GREEN}✓${NC} Processes killed"
    else
        echo -e "  ${YELLOW}⚠${NC} No processes to kill"
    fi
fi

# Verify nothing is listening on port
if lsof -i :$PROXY_PORT > /dev/null 2>&1; then
    echo -e "  ${RED}✗${NC} Port $PROXY_PORT still in use!"
    echo -e "  Run: ${YELLOW}sudo lsof -i :$PROXY_PORT${NC}"
    exit 1
else
    echo -e "  ${GREEN}✓${NC} Port $PROXY_PORT is free"
fi

echo ""

# ================================
# Step 3: Cleanup environment
# ================================
echo -e "${YELLOW}[3/7] Cleaning up environment...${NC}"

unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY 2>/dev/null || true
unset ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL 2>/dev/null || true
unset ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_SUBAGENT_MODEL 2>/dev/null || true
unset CLAUDE_CODE_EFFORT_LEVEL 2>/dev/null || true

echo -e "  ${GREEN}✓${NC} Environment variables cleared"
echo ""

# ================================
# Step 4: Git pull updates
# ================================
echo -e "${YELLOW}[4/7] Pulling latest changes...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "  Current branch: ${BLUE}$CURRENT_BRANCH${NC}"

# Fetch updates
git fetch origin

# Checkout windows-fixes if not already
if [[ "$CURRENT_BRANCH" != "windows-fixes" ]]; then
    echo -e "  Switching to windows-fixes branch..."
    git checkout windows-fixes
fi

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo -e "  ${YELLOW}⚠${NC} Uncommitted changes detected:"
    git status -s
    read -p "  Stash changes and continue? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash
        echo -e "  ${GREEN}✓${NC} Changes stashed"
    else
        echo -e "  ${RED}✗${NC} Deploy cancelled"
        exit 1
    fi
fi

# Pull updates
BEFORE_COMMIT=$(git rev-parse HEAD)
git pull origin windows-fixes

AFTER_COMMIT=$(git rev-parse HEAD)
if [[ "$BEFORE_COMMIT" == "$AFTER_COMMIT" ]]; then
    echo -e "  ${GREEN}✓${NC} Already up to date"
else
    echo -e "  ${GREEN}✓${NC} Updated from $BEFORE_COMMIT to $AFTER_COMMIT"
    echo -e "  Recent changes:"
    git log --oneline --no-decorate $BEFORE_COMMIT..$AFTER_COMMIT | head -5
fi

echo ""

# ================================
# Step 5: Check API keys
# ================================
echo -e "${YELLOW}[5/7] Checking API keys...${NC}"

# Check for .env file
if [[ -f .env ]]; then
    echo -e "  ${GREEN}✓${NC} Found .env file"
    source .env
elif [[ -f ~/.env ]]; then
    echo -e "  ${GREEN}✓${NC} Found ~/.env file"
    source ~/.env
fi

# Verify keys
KEYS_OK=true
if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    echo -e "  ${RED}✗${NC} DEEPSEEK_API_KEY not set"
    KEYS_OK=false
else
    echo -e "  ${GREEN}✓${NC} DEEPSEEK_API_KEY: ****${DEEPSEEK_API_KEY: -4}"
fi

if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    echo -e "  ${GREEN}✓${NC} OPENROUTER_API_KEY: ****${OPENROUTER_API_KEY: -4}"
fi

if [[ -n "${FIREWORKS_API_KEY:-}" ]]; then
    echo -e "  ${GREEN}✓${NC} FIREWORKS_API_KEY: ****${FIREWORKS_API_KEY: -4}"
fi

if [[ "$KEYS_OK" == "false" ]]; then
    echo -e "  ${RED}✗${NC} Missing required API keys!"
    echo -e "  Set via: ${YELLOW}export DEEPSEEK_API_KEY=sk-...${NC}"
    echo -e "  Or add to .env file in repo root"
    exit 1
fi

echo ""

# ================================
# Step 6: Start proxy
# ================================
echo -e "${YELLOW}[6/7] Starting proxy...${NC}"

if [[ "$DEPLOY_MODE" == "systemd" ]]; then
    # Check if service file exists
    if [[ ! -f /etc/systemd/system/deepclaude-proxy.service ]]; then
        echo -e "  ${YELLOW}⚠${NC} systemd service file not found"
        echo -e "  Creating service file..."

        sudo tee /etc/systemd/system/deepclaude-proxy.service > /dev/null << EOF
[Unit]
Description=DeepClaude Model Proxy
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR
Environment="DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}"
Environment="OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}"
Environment="FIREWORKS_API_KEY=${FIREWORKS_API_KEY:-}"
ExecStart=/usr/bin/node proxy/start-proxy.js --mode deepseek --port $PROXY_PORT
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable deepclaude-proxy
        echo -e "  ${GREEN}✓${NC} Service file created and enabled"
    fi

    # Start service
    echo -e "  Starting systemd service..."
    sudo systemctl start deepclaude-proxy
    sleep 2

    if systemctl is-active --quiet deepclaude-proxy; then
        echo -e "  ${GREEN}✓${NC} Service started successfully"
    else
        echo -e "  ${RED}✗${NC} Service failed to start!"
        echo -e "  Check logs: ${YELLOW}journalctl -u deepclaude-proxy -n 20${NC}"
        exit 1
    fi
else
    # Manual mode: background process
    echo -e "  Starting background process..."
    export DEEPSEEK_API_KEY OPENROUTER_API_KEY FIREWORKS_API_KEY
    nohup node proxy/start-proxy.js --mode deepseek --port $PROXY_PORT > /tmp/deepclaude.log 2>&1 &
    PROXY_PID=$!
    echo -e "  ${GREEN}✓${NC} Started with PID: $PROXY_PID"
    echo -e "  Logs: ${YELLOW}tail -f /tmp/deepclaude.log${NC}"
    sleep 2
fi

echo ""

# ================================
# Step 7: Verify deployment
# ================================
echo -e "${YELLOW}[7/7] Verifying deployment...${NC}"

# Wait for proxy to be ready
RETRY_COUNT=0
MAX_RETRIES=10
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -s --connect-timeout 2 http://127.0.0.1:$PROXY_PORT/_proxy/status > /dev/null 2>&1; then
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 1
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
    echo -e "  ${RED}✗${NC} Proxy not responding after $MAX_RETRIES seconds"
    echo -e "  Check logs:"
    if [[ "$DEPLOY_MODE" == "systemd" ]]; then
        journalctl -u deepclaude-proxy -n 20 --no-pager
    else
        tail -20 /tmp/deepclaude.log
    fi
    exit 1
fi

# Get status
STATUS=$(curl -s http://127.0.0.1:$PROXY_PORT/_proxy/status)
echo -e "  ${GREEN}✓${NC} Proxy is responding"
echo ""
echo -e "  Status:"
echo "$STATUS" | grep -E '"mode"|"uptime"|"requests"' | sed 's/^/    /'

# Reset state (fresh start)
echo ""
echo -e "  Resetting proxy state..."
curl -sX POST http://127.0.0.1:$PROXY_PORT/_proxy/reset > /dev/null
echo -e "  ${GREEN}✓${NC} State reset complete"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Deploy Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Useful commands:"
echo -e "  Status:  ${BLUE}curl -s http://127.0.0.1:$PROXY_PORT/_proxy/status | jq${NC}"
echo -e "  Cost:    ${BLUE}curl -s http://127.0.0.1:$PROXY_PORT/_proxy/cost | jq${NC}"
echo -e "  Switch:  ${BLUE}curl -sX POST http://127.0.0.1:$PROXY_PORT/_proxy/mode -d backend=deepseek${NC}"
echo -e "  Reset:   ${BLUE}curl -sX POST http://127.0.0.1:$PROXY_PORT/_proxy/reset${NC}"

if [[ "$DEPLOY_MODE" == "systemd" ]]; then
    echo ""
    echo -e "systemd commands:"
    echo -e "  Status:  ${BLUE}sudo systemctl status deepclaude-proxy${NC}"
    echo -e "  Logs:    ${BLUE}journalctl -u deepclaude-proxy -f${NC}"
    echo -e "  Restart: ${BLUE}sudo systemctl restart deepclaude-proxy${NC}"
    echo -e "  Stop:    ${BLUE}sudo systemctl stop deepclaude-proxy${NC}"
else
    echo ""
    echo -e "Manual mode:"
    echo -e "  Logs:    ${BLUE}tail -f /tmp/deepclaude.log${NC}"
    echo -e "  Stop:    ${BLUE}pkill -f 'node.*start-proxy'${NC}"
fi

echo ""
