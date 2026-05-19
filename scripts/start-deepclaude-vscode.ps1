# Start DeepClaude proxy + VSCode with DeepSeek env vars
# VSCode extension will use the proxy on port 3200

param(
    [string]$Path = "."
)

# Find repo directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir

$possibleRepoPaths = @(
    $repoDir,
    "$env:USERPROFILE\projects\deepclaude",
    "C:\Users\Administrator\projects\deepclaude",
    "D:\projects\deepclaude"
)

$proxyScript = $null
foreach ($p in $possibleRepoPaths) {
    $testPath = Join-Path $p "proxy\start-proxy.js"
    if (Test-Path $testPath) {
        $proxyScript = $testPath
        break
    }
}

if (-not $proxyScript) {
    Write-Host "[ERROR] Could not find proxy/start-proxy.js" -ForegroundColor Red
    exit 1
}

# Check if proxy is already running
$proxy = Get-NetTCPConnection -LocalPort 3200 -State Listen -ErrorAction SilentlyContinue
if (-not $proxy) {
    Write-Host "[INFO] Starting proxy on port 3200..." -ForegroundColor Cyan
    Start-Process -WindowStyle Hidden -FilePath "node" -ArgumentList "`"$proxyScript`"", "--mode", "deepseek", "--port", "3200"
    Start-Sleep -Seconds 2

    $proxy = Get-NetTCPConnection -LocalPort 3200 -State Listen -ErrorAction SilentlyContinue
    if ($proxy) {
        Write-Host "[OK] Proxy started on port 3200" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to start proxy" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[OK] Proxy already running on port 3200" -ForegroundColor Green
}

# Set DeepSeek env vars for this session
$env:ANTHROPIC_AUTH_TOKEN = "unused"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "deepseek-v4-pro"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "deepseek-v4-pro"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "deepseek-v4-flash"
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:3200"
$env:CLAUDE_CODE_SUBAGENT_MODEL = "deepseek-v4-flash"

# Launch VSCode with env vars inherited
Write-Host "[INFO] Launching VSCode at: $Path" -ForegroundColor Cyan
code $Path
