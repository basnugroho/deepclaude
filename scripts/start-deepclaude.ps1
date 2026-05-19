# Start DeepClaude proxy (if not running) + Claude with DeepSeek

# Load API keys from .env file (check multiple locations)
$envFiles = @(
    ".\.env",                                    # Current directory
    "$PWD\.env",                                 # PWD
    "$env:USERPROFILE\projects\deepclaude\.env", # Default Windows location
    "$env:USERPROFILE\.deepclaude-keys"          # Home fallback
)
foreach ($envFile in $envFiles) {
    if (Test-Path $envFile) {
        Write-Host "[INFO] Loading keys from: $envFile" -ForegroundColor Cyan
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.+)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                [Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
        break
    }
}

# Find repo directory (look for proxy/start-proxy.js)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir

# Fallback paths to check
$possibleRepoPaths = @(
    $repoDir,
    "$env:USERPROFILE\projects\deepclaude",
    "C:\Users\Administrator\projects\deepclaude",
    "D:\projects\deepclaude"
)

$proxyScript = $null
foreach ($path in $possibleRepoPaths) {
    $testPath = Join-Path $path "proxy\start-proxy.js"
    if (Test-Path $testPath) {
        $proxyScript = $testPath
        break
    }
}

if (-not $proxyScript) {
    Write-Host "[ERROR] Could not find proxy/start-proxy.js" -ForegroundColor Red
    Write-Host "Please set DEEPCLAUDE_REPO environment variable to repo path" -ForegroundColor Red
    exit 1
}

# Kill existing proxy on port 3200 and start fresh
$existingProxy = Get-NetTCPConnection -LocalPort 3200 -State Listen -ErrorAction SilentlyContinue
if ($existingProxy) {
    Write-Host "[INFO] Stopping existing proxy..." -ForegroundColor Yellow
    $existingProxy | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
}

Write-Host "[INFO] Starting proxy on port 3200..." -ForegroundColor Cyan
Start-Process -WindowStyle Hidden -FilePath "node" -ArgumentList "`"$proxyScript`"", "--mode", "deepseek", "--port", "3200"
Start-Sleep -Seconds 2

# Verify proxy started
$proxy = Get-NetTCPConnection -LocalPort 3200 -State Listen -ErrorAction SilentlyContinue
if ($proxy) {
    Write-Host "[OK] Proxy started on port 3200" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to start proxy" -ForegroundColor Red
    exit 1
}

# Set DeepSeek env vars
$env:ANTHROPIC_AUTH_TOKEN = "unused"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "deepseek-v4-pro"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "deepseek-v4-pro"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "deepseek-v4-flash"
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:3200"
$env:CLAUDE_CODE_SUBAGENT_MODEL = "deepseek-v4-flash"

# Launch Claude
claude @args
