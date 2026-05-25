#!/usr/bin/env pwsh
# diagnose-issue.ps1 - Diagnose dan kill semua yang related ke proxy

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  DeepClaude Diagnostic Tool" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check all running Node processes
Write-Host "[1] Checking Node.js processes..." -ForegroundColor Yellow
$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    Write-Host "  ⚠ Found Node.js processes:" -ForegroundColor Red
    $nodeProcesses | Format-Table Id, ProcessName, StartTime, @{Name="Memory(MB)";Expression={[math]::Round($_.WS/1MB,2)}} -AutoSize

    Write-Host ""
    $kill = Read-Host "  Kill all Node processes? (y/N)"
    if ($kill -eq 'y' -or $kill -eq 'Y') {
        Stop-Process -Name node -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ All Node processes killed" -ForegroundColor Green
    }
} else {
    Write-Host "  ✓ No Node.js processes running" -ForegroundColor Green
}

# 2. Check port 3200
Write-Host ""
Write-Host "[2] Checking port 3200..." -ForegroundColor Yellow
$port3200 = netstat -ano | Select-String ":3200"
if ($port3200) {
    Write-Host "  ⚠ Port 3200 is in use:" -ForegroundColor Red
    $port3200 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

    # Extract PID and kill
    $port3200 | ForEach-Object {
        if ($_ -match "\s+(\d+)\s*$") {
            $pid = $matches[1]
            Write-Host ""
            $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($process) {
                Write-Host "  Process: $($process.ProcessName) (PID: $pid)" -ForegroundColor Yellow
                $kill = Read-Host "  Kill this process? (y/N)"
                if ($kill -eq 'y' -or $kill -eq 'Y') {
                    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                    Write-Host "  ✓ Process killed" -ForegroundColor Green
                }
            }
        }
    }
} else {
    Write-Host "  ✓ Port 3200 is free" -ForegroundColor Green
}

# 3. Check environment variables (all levels)
Write-Host ""
Write-Host "[3] Checking environment variables..." -ForegroundColor Yellow

$checkVars = @("ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "DEEPSEEK_API_KEY")
$found = $false

foreach ($var in $checkVars) {
    $userVal = [Environment]::GetEnvironmentVariable($var, "User")
    $machineVal = [Environment]::GetEnvironmentVariable($var, "Machine")
    $processVal = [Environment]::GetEnvironmentVariable($var, "Process")

    if ($userVal -or $machineVal -or $processVal) {
        $found = $true
        Write-Host "  ⚠ Found: $var" -ForegroundColor Red
        if ($userVal) { Write-Host "    User:    $userVal" -ForegroundColor Gray }
        if ($machineVal) { Write-Host "    Machine: $machineVal" -ForegroundColor Gray }
        if ($processVal) { Write-Host "    Process: $processVal" -ForegroundColor Gray }
    }
}

if (-not $found) {
    Write-Host "  ✓ No problematic env vars found" -ForegroundColor Green
} else {
    Write-Host ""
    $clean = Read-Host "  Clean all these env vars? (y/N)"
    if ($clean -eq 'y' -or $clean -eq 'Y') {
        foreach ($var in $checkVars) {
            [Environment]::SetEnvironmentVariable($var, $null, "User")
            Remove-Item "Env:$var" -ErrorAction SilentlyContinue
        }
        Write-Host "  ✓ Environment variables cleaned" -ForegroundColor Green
    }
}

# 4. Check .env file
Write-Host ""
Write-Host "[4] Checking .env file..." -ForegroundColor Yellow
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Write-Host "  ⚠ Found .env file:" -ForegroundColor Yellow
    Write-Host "    $envFile" -ForegroundColor Gray

    $content = Get-Content $envFile -ErrorAction SilentlyContinue
    if ($content -match "DEEPSEEK_API_KEY|ANTHROPIC") {
        Write-Host "    Content preview:" -ForegroundColor Gray
        $content | Select-Object -First 10 | ForEach-Object {
            if ($_ -notmatch "^#") {
                Write-Host "      $_" -ForegroundColor Gray
            }
        }
    }

    Write-Host ""
    $disable = Read-Host "  Disable .env file? (rename to .env.disabled) (y/N)"
    if ($disable -eq 'y' -or $disable -eq 'Y') {
        Rename-Item $envFile ".env.disabled" -Force
        Write-Host "  ✓ .env renamed to .env.disabled" -ForegroundColor Green
    }
} else {
    Write-Host "  ✓ No .env file found (OK)" -ForegroundColor Green
}

# 5. Check VSCode settings
Write-Host ""
Write-Host "[5] Checking VSCode settings..." -ForegroundColor Yellow
$vscodeSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $vscodeSettings) {
    $content = Get-Content $vscodeSettings -Raw -ErrorAction SilentlyContinue
    if ($content -match "ANTHROPIC_BASE_URL|127\.0\.0\.1:3200") {
        Write-Host "  ⚠ Found proxy settings in VSCode User settings!" -ForegroundColor Red
        Write-Host "    $vscodeSettings" -ForegroundColor Gray
        Write-Host ""
        $open = Read-Host "  Open file to edit manually? (y/N)"
        if ($open -eq 'y' -or $open -eq 'Y') {
            code $vscodeSettings
        }
    } else {
        Write-Host "  ✓ VSCode User settings clean" -ForegroundColor Green
    }
} else {
    Write-Host "  ℹ VSCode settings not found" -ForegroundColor Gray
}

# 6. Check Claude config
Write-Host ""
Write-Host "[6] Checking Claude config..." -ForegroundColor Yellow
$claudeConfig = "$env:USERPROFILE\.claude\config.json"
if (Test-Path $claudeConfig) {
    $content = Get-Content $claudeConfig -Raw -ErrorAction SilentlyContinue
    if ($content -match "127\.0\.0\.1:3200|localhost:3200") {
        Write-Host "  ⚠ Found proxy in Claude config!" -ForegroundColor Red
        Write-Host "    $claudeConfig" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Content:" -ForegroundColor Gray
        Write-Host $content -ForegroundColor Gray
        Write-Host ""
        $reset = Read-Host "  Reset Claude config? (this will logout) (y/N)"
        if ($reset -eq 'y' -or $reset -eq 'Y') {
            Remove-Item "$env:USERPROFILE\.claude" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Claude config reset (please run: claude login)" -ForegroundColor Green
        }
    } else {
        Write-Host "  ✓ Claude config clean" -ForegroundColor Green
    }
} else {
    Write-Host "  ℹ Claude config not found" -ForegroundColor Gray
}

# 7. Check shell profiles
Write-Host ""
Write-Host "[7] Checking PowerShell profiles..." -ForegroundColor Yellow
$profiles = @($PROFILE.CurrentUserCurrentHost, $PROFILE.CurrentUserAllHosts)
$foundProfile = $false
foreach ($prof in $profiles) {
    if (Test-Path $prof) {
        $content = Get-Content $prof -Raw -ErrorAction SilentlyContinue
        if ($content -match "ANTHROPIC_BASE_URL|127\.0\.0\.1:3200|deepclaude") {
            $foundProfile = $true
            Write-Host "  ⚠ Found proxy settings in profile:" -ForegroundColor Red
            Write-Host "    $prof" -ForegroundColor Gray
        }
    }
}
if (-not $foundProfile) {
    Write-Host "  ✓ PowerShell profiles clean" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Diagnosis Complete" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Recommended next steps:" -ForegroundColor Yellow
Write-Host "  1. Close this PowerShell window" -ForegroundColor White
Write-Host "  2. Close all VSCode windows" -ForegroundColor White
Write-Host "  3. Open a NEW PowerShell window" -ForegroundColor White
Write-Host "  4. Run: claude logout && claude login" -ForegroundColor White
Write-Host "  5. Test: claude" -ForegroundColor White
Write-Host ""
Write-Host "If still not working:" -ForegroundColor Yellow
Write-Host "  - Restart your computer (clears all Process-level env vars)" -ForegroundColor White
Write-Host ""
