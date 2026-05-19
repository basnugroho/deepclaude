# Claude with DeepSeek via proxy
# Requires proxy to be running on port 3200

$env:ANTHROPIC_AUTH_TOKEN = "unused"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "deepseek-v4-pro"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "deepseek-v4-pro"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "deepseek-v4-flash"
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:3200"
$env:CLAUDE_CODE_SUBAGENT_MODEL = "deepseek-v4-flash"

# Check if proxy is running
$proxy = Get-NetTCPConnection -LocalPort 3200 -State Listen -ErrorAction SilentlyContinue
if (-not $proxy) {
    Write-Host "[WARN] Proxy not running on port 3200. Start with: start-deepclaude" -ForegroundColor Yellow
}

claude @args
