# fix-connection.ps1 - Quick fix untuk connection refused
# Simple version tanpa interactive prompts

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  Fixing Connection Issues" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 1. Kill Node processes
Write-Host "[1] Stopping Node.js processes..." -ForegroundColor Yellow
$nodeProcs = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeProcs) {
    Stop-Process -Name node -Force -ErrorAction SilentlyContinue
    Write-Host "    Killed $($nodeProcs.Count) Node.js process(es)" -ForegroundColor Green
} else {
    Write-Host "    No Node.js processes found" -ForegroundColor Gray
}

# 2. Kill processes using port 3200
Write-Host ""
Write-Host "[2] Freeing port 3200..." -ForegroundColor Yellow
$port3200 = netstat -ano | Select-String ":3200"
if ($port3200) {
    $port3200 | ForEach-Object {
        if ($_ -match "\s+(\d+)\s*$") {
            $pid = $matches[1]
            try {
                Stop-Process -Id $pid -Force -ErrorAction Stop
                Write-Host "    Killed process PID: $pid" -ForegroundColor Green
            } catch {
                Write-Host "    Could not kill PID: $pid" -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "    Port 3200 is free" -ForegroundColor Gray
}

# 3. Remove environment variables
Write-Host ""
Write-Host "[3] Cleaning environment variables..." -ForegroundColor Yellow
$vars = @(
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_AUTH_TOKEN",
    "DEEPSEEK_API_KEY",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "CLAUDE_CODE_SUBAGENT_MODEL"
)

foreach ($var in $vars) {
    [Environment]::SetEnvironmentVariable($var, $null, "User")
    Remove-Item "Env:$var" -ErrorAction SilentlyContinue
}
Write-Host "    Cleaned $($vars.Count) environment variables" -ForegroundColor Green

# 4. Check .env file
Write-Host ""
Write-Host "[4] Checking .env file..." -ForegroundColor Yellow
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Rename-Item $envFile ".env.disabled.$timestamp" -Force
    Write-Host "    Renamed .env to .env.disabled.$timestamp" -ForegroundColor Green
} else {
    Write-Host "    No .env file found" -ForegroundColor Gray
}

# 5. Verification
Write-Host ""
Write-Host "[5] Verification..." -ForegroundColor Yellow
$remaining = Get-ChildItem Env: | Where-Object { $_.Name -like "*ANTHROPIC*" }
if ($remaining) {
    Write-Host "    Warning: Some env vars still in current session" -ForegroundColor Yellow
    Write-Host "    (Will be cleared when you restart PowerShell)" -ForegroundColor Gray
} else {
    Write-Host "    All environment variables cleared" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "  Fix Complete!" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Close this PowerShell window" -ForegroundColor White
Write-Host "  2. Close ALL VSCode windows" -ForegroundColor White
Write-Host "  3. Open a NEW PowerShell" -ForegroundColor White
Write-Host "  4. Test: claude" -ForegroundColor Cyan
Write-Host ""
Write-Host "If still not working, run:" -ForegroundColor Yellow
Write-Host "  claude logout" -ForegroundColor Cyan
Write-Host "  claude login" -ForegroundColor Cyan
Write-Host "  claude" -ForegroundColor Cyan
Write-Host ""
