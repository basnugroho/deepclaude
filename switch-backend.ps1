# switch-backend.ps1 - Simple one-command backend switcher for Windows
# Usage: .\switch-backend.ps1 [anthropic|deepseek|status]

param(
    [Parameter(Position=0)]
    [ValidateSet("anthropic", "deepseek", "ds", "status", $null)]
    [string]$Backend
)

function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\switch-backend.ps1 anthropic   # Switch to Anthropic (original Claude)"
    Write-Host "  .\switch-backend.ps1 deepseek    # Switch to DeepSeek (cheap, no vision)"
    Write-Host "  .\switch-backend.ps1 status      # Show current backend"
    Write-Host ""
}

function Show-Status {
    Write-Host "=== Current Backend Status ===" -ForegroundColor Cyan
    Write-Host ""

    # Check if proxy process is running
    $proxyProcess = Get-Process -Name node -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*proxy*" }
    if ($proxyProcess) {
        Write-Host "  Proxy Process:   " -NoNewline
        Write-Host "RUNNING" -ForegroundColor Green
    } else {
        Write-Host "  Proxy Process:   " -NoNewline
        Write-Host "STOPPED" -ForegroundColor Yellow
    }

    # Check port 3200
    $port3200 = netstat -ano | Select-String ":3200"
    if ($port3200) {
        Write-Host "  Port 3200:       " -NoNewline
        Write-Host "IN USE" -ForegroundColor Green -NoNewline
        Write-Host " (proxy running)"
    } else {
        Write-Host "  Port 3200:       " -NoNewline
        Write-Host "FREE" -ForegroundColor Yellow
    }

    # Check env var
    $baseUrl = $env:ANTHROPIC_BASE_URL
    if ($baseUrl) {
        Write-Host "  Env Variable:    " -NoNewline
        Write-Host $baseUrl -ForegroundColor Green
    } else {
        Write-Host "  Env Variable:    " -NoNewline
        Write-Host "Not set" -ForegroundColor Yellow
    }

    Write-Host ""
    if ($port3200 -and $baseUrl) {
        Write-Host "  Current Backend: " -NoNewline
        Write-Host "DeepSeek (via proxy)" -ForegroundColor Green
        Write-Host "  Note: Vision/image support disabled" -ForegroundColor Yellow
    } elseif (-not $baseUrl) {
        Write-Host "  Current Backend: " -NoNewline
        Write-Host "Anthropic (original Claude)" -ForegroundColor Green
        Write-Host "  Note: Full features including vision" -ForegroundColor Yellow
    } else {
        Write-Host "  Current Backend: " -NoNewline
        Write-Host "Unknown/Mixed state" -ForegroundColor Red
    }
    Write-Host ""
}

function Switch-ToAnthropic {
    Write-Host "=== Switching to Anthropic ===" -ForegroundColor Cyan
    Write-Host ""

    # Stop Node processes
    Write-Host "  [1/4] Stopping proxy processes..."
    $nodeProcs = Get-Process -Name node -ErrorAction SilentlyContinue
    if ($nodeProcs) {
        Stop-Process -Name node -Force -ErrorAction SilentlyContinue
        Write-Host "    ✓ Processes stopped" -ForegroundColor Green
    } else {
        Write-Host "    ℹ No processes found" -ForegroundColor Yellow
    }

    # Free port 3200
    Write-Host "  [2/4] Freeing port 3200..."
    $port3200 = netstat -ano | Select-String ":3200"
    if ($port3200) {
        $port3200 | ForEach-Object {
            if ($_ -match "\s+(\d+)\s*$") {
                Stop-Process -Id $matches[1] -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "    ✓ Port freed" -ForegroundColor Green
    } else {
        Write-Host "    ℹ Port already free" -ForegroundColor Yellow
    }

    # Remove env vars
    Write-Host "  [3/4] Clearing environment variables..."
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $null, "User")
    Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    Write-Host "    ✓ Variables cleared" -ForegroundColor Green

    # Disable .env
    Write-Host "  [4/4] Disabling .env file..."
    $envFile = Join-Path $PSScriptRoot ".env"
    if (Test-Path $envFile) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Rename-Item $envFile ".env.disabled.$timestamp" -Force
        Write-Host "    ✓ .env disabled" -ForegroundColor Green
    } else {
        Write-Host "    ℹ No .env file found" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "✓ Switched to Anthropic!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Important:" -ForegroundColor Yellow
    Write-Host "  - Close this PowerShell window"
    Write-Host "  - Open a NEW PowerShell window"
    Write-Host "  - Then test: claude"
    Write-Host ""
}

function Switch-ToDeepSeek {
    Write-Host "=== Switching to DeepSeek ===" -ForegroundColor Cyan
    Write-Host ""

    # Check .env file
    Write-Host "  [1/5] Checking .env file..."
    $envFile = Join-Path $PSScriptRoot ".env"
    if (-not (Test-Path $envFile)) {
        # Try to restore from backup
        $disabledEnv = Get-ChildItem "$PSScriptRoot\.env.disabled.*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($disabledEnv) {
            Copy-Item $disabledEnv.FullName $envFile -Force
            Write-Host "    ✓ .env restored from backup" -ForegroundColor Green
        } else {
            Write-Host "    ✗ No .env file found!" -ForegroundColor Red
            Write-Host "  Please create .env with DEEPSEEK_API_KEY"
            Write-Host "  Example: Copy-Item .env.example .env"
            exit 1
        }
    } else {
        Write-Host "    ✓ .env found" -ForegroundColor Green
    }

    # Load .env
    Write-Host "  [2/5] Loading API key..."
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }

    if (-not $env:DEEPSEEK_API_KEY) {
        Write-Host "    ✗ DEEPSEEK_API_KEY not set in .env" -ForegroundColor Red
        exit 1
    }
    Write-Host "    ✓ API key loaded" -ForegroundColor Green

    # Start proxy
    Write-Host "  [3/5] Starting proxy..."
    $proxyScript = Join-Path $PSScriptRoot "proxy\start-proxy.js"
    $proxyProcess = Start-Process -FilePath "node" -ArgumentList $proxyScript, "--mode", "deepseek", "--port", "3200" -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 3
    Write-Host "    ✓ Proxy started (PID: $($proxyProcess.Id))" -ForegroundColor Green

    # Set env var
    Write-Host "  [4/5] Setting environment variable..."
    [Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://127.0.0.1:3200", "User")
    $env:ANTHROPIC_BASE_URL = "http://127.0.0.1:3200"
    Write-Host "    ✓ ANTHROPIC_BASE_URL set" -ForegroundColor Green

    # Verify
    Write-Host "  [5/5] Verifying proxy..."
    Start-Sleep -Seconds 1
    try {
        $status = Invoke-WebRequest -Uri "http://127.0.0.1:3200/_proxy/status" -UseBasicParsing -ErrorAction Stop
        Write-Host "    ✓ Proxy is responding" -ForegroundColor Green
    } catch {
        Write-Host "    ✗ Proxy not responding" -ForegroundColor Red
        Write-Host "    Error: $_"
        exit 1
    }

    Write-Host ""
    Write-Host "✓ Switched to DeepSeek!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Important:" -ForegroundColor Yellow
    Write-Host "  - Close this PowerShell window"
    Write-Host "  - Open a NEW PowerShell window"
    Write-Host "  - Then test: claude"
    Write-Host ""
    Write-Host "Note: Vision/image support disabled with DeepSeek" -ForegroundColor Red
    Write-Host ""
}

# Main
if (-not $Backend) {
    Write-Host "Error: Missing argument" -ForegroundColor Red
    Write-Host ""
    Show-Usage
    exit 1
}

switch ($Backend) {
    "anthropic" {
        Switch-ToAnthropic
    }
    { $_ -in "deepseek", "ds" } {
        Switch-ToDeepSeek
    }
    "status" {
        Show-Status
    }
}
