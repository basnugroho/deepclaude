#!/usr/bin/env pwsh
# reset-to-normal.ps1 - Reset DeepClaude dan kembali ke Claude normal

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  DeepClaude Reset Script" -ForegroundColor Cyan
Write-Host "  Kembali ke Claude Normal" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Stop semua proxy
Write-Host "[1/7] Stopping proxy processes..." -ForegroundColor Yellow
Stop-Process -Name node -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Write-Host "  ✓ Proxy stopped" -ForegroundColor Green

# Step 2: Backup dan rename file .env
Write-Host ""
Write-Host "[2/7] Backing up .env file..." -ForegroundColor Yellow
$envFile = "$PSScriptRoot\.env"
if (Test-Path $envFile) {
    $backupFile = "$PSScriptRoot\.env.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $envFile $backupFile -Force
    Rename-Item $envFile ".env.disabled" -Force
    Write-Host "  ✓ .env backed up to: .env.backup.*" -ForegroundColor Green
    Write-Host "  ✓ .env renamed to: .env.disabled" -ForegroundColor Green
} else {
    Write-Host "  ℹ .env not found (OK)" -ForegroundColor Gray
}

# Step 3: Hapus environment variables (User level - permanent)
Write-Host ""
Write-Host "[3/7] Removing permanent environment variables..." -ForegroundColor Yellow
$envVars = @(
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_API_KEY",
    "DEEPSEEK_API_KEY",
    "OPENROUTER_API_KEY",
    "FIREWORKS_API_KEY",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "CLAUDE_CODE_SUBAGENT_MODEL",
    "CLAUDE_CODE_EFFORT_LEVEL"
)

foreach ($var in $envVars) {
    [Environment]::SetEnvironmentVariable($var, $null, "User")
    Remove-Item "Env:$var" -ErrorAction SilentlyContinue
}
Write-Host "  ✓ Environment variables cleared" -ForegroundColor Green

# Step 4: Reset VSCode User Settings
Write-Host ""
Write-Host "[4/7] Checking VSCode settings..." -ForegroundColor Yellow
$vscodeSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $vscodeSettings) {
    $content = Get-Content $vscodeSettings -Raw -ErrorAction SilentlyContinue
    if ($content -match "ANTHROPIC_BASE_URL" -or $content -match "127.0.0.1:3200") {
        Write-Host "  ⚠ Found proxy settings in VSCode!" -ForegroundColor Yellow
        Write-Host "    Please manually remove ANTHROPIC_BASE_URL from:" -ForegroundColor Yellow
        Write-Host "    $vscodeSettings" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    Or run: code '$vscodeSettings'" -ForegroundColor Cyan
    } else {
        Write-Host "  ✓ VSCode settings clean" -ForegroundColor Green
    }
} else {
    Write-Host "  ℹ VSCode settings not found (OK)" -ForegroundColor Gray
}

# Step 5: Reset VSCode Workspace Settings
Write-Host ""
Write-Host "[5/7] Checking VSCode workspace settings..." -ForegroundColor Yellow
$workspaceSettings = "$PSScriptRoot\.vscode\settings.json"
if (Test-Path $workspaceSettings) {
    $content = Get-Content $workspaceSettings -Raw -ErrorAction SilentlyContinue
    if ($content -match "ANTHROPIC_BASE_URL" -or $content -match "127.0.0.1:3200") {
        Write-Host "  ⚠ Found proxy settings in workspace!" -ForegroundColor Yellow
        $backup = "$workspaceSettings.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $workspaceSettings $backup -Force
        Write-Host "    Backed up to: .vscode\settings.json.backup.*" -ForegroundColor Yellow
        Write-Host "    Please manually clean: $workspaceSettings" -ForegroundColor Yellow
    } else {
        Write-Host "  ✓ Workspace settings clean" -ForegroundColor Green
    }
} else {
    Write-Host "  ℹ Workspace settings not found (OK)" -ForegroundColor Gray
}

# Step 6: Verify port 3200 is free
Write-Host ""
Write-Host "[6/7] Checking port 3200..." -ForegroundColor Yellow
$portCheck = netstat -ano | Select-String ":3200"
if ($portCheck) {
    Write-Host "  ⚠ Port 3200 still in use:" -ForegroundColor Yellow
    Write-Host "    $portCheck" -ForegroundColor Gray
    Write-Host "    You may need to restart your computer" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Port 3200 is free" -ForegroundColor Green
}

# Step 7: Verification
Write-Host ""
Write-Host "[7/7] Final verification..." -ForegroundColor Yellow
$remaining = Get-ChildItem Env: | Where-Object {
    $_.Name -like "*ANTHROPIC*" -or
    $_.Name -like "*CLAUDE*" -or
    $_.Name -like "*DEEPSEEK*"
}
if ($remaining) {
    Write-Host "  ⚠ Some env vars still in current session:" -ForegroundColor Yellow
    $remaining | ForEach-Object { Write-Host "    - $($_.Name) = $($_.Value)" -ForegroundColor Gray }
    Write-Host "    These will be cleared when you restart PowerShell" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ All env vars cleared" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Reset Complete!" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Close this PowerShell window" -ForegroundColor White
Write-Host "  2. Close VSCode if open" -ForegroundColor White
Write-Host "  3. Open a NEW PowerShell window" -ForegroundColor White
Write-Host "  4. Test: claude" -ForegroundColor White
Write-Host ""
Write-Host "If still having issues:" -ForegroundColor Yellow
Write-Host "  - Restart your computer (recommended)" -ForegroundColor White
Write-Host "  - Or run: claude logout && claude login" -ForegroundColor White
Write-Host ""
Write-Host "To restore DeepClaude later:" -ForegroundColor Cyan
Write-Host "  - Rename .env.disabled back to .env" -ForegroundColor White
Write-Host "  - Run: .\deepclaude.ps1" -ForegroundColor White
Write-Host ""
