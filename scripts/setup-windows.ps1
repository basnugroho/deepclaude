# DeepClaude Windows Setup Script
# Run this once to install launcher scripts

$binDir = "$env:USERPROFILE\bin"
$repoDir = Split-Path -Parent $PSScriptRoot

# Create bin directory
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    Write-Host "[OK] Created $binDir"
}

# Add to PATH if not already
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binDir", "User")
    $env:Path = "$env:Path;$binDir"
    Write-Host "[OK] Added $binDir to PATH"
} else {
    Write-Host "[OK] $binDir already in PATH"
}

# Copy launcher scripts
Copy-Item "$repoDir\scripts\claude-deepseek.ps1" "$binDir\" -Force
Copy-Item "$repoDir\scripts\claude-anthropic.ps1" "$binDir\" -Force
Copy-Item "$repoDir\scripts\start-deepclaude.ps1" "$binDir\" -Force
Copy-Item "$repoDir\scripts\start-deepclaude-vscode.ps1" "$binDir\" -Force
Write-Host "[OK] Copied launcher scripts to $binDir"

# Create slash commands directory
$commandsDir = "$env:USERPROFILE\.claude\commands"
if (-not (Test-Path $commandsDir)) {
    New-Item -ItemType Directory -Path $commandsDir -Force | Out-Null
}

# Install slash commands
Set-Content "$commandsDir\deepseek.md" "Run curl.exe -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=deepseek silently, then just say in 3 words: Switched to DeepSeek."
Set-Content "$commandsDir\anthropic.md" "Run curl.exe -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=anthropic silently, then just say in 3 words: Switched to Anthropic."
Set-Content "$commandsDir\openrouter.md" "Run curl.exe -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=openrouter silently, then just say in 3 words: Switched to OpenRouter."
Set-Content "$commandsDir\proxy-status.md" "Run curl.exe -s http://127.0.0.1:3200/_proxy/status silently, then show the JSON output formatted nicely."
Set-Content "$commandsDir\proxy-cost.md" "Run curl.exe -s http://127.0.0.1:3200/_proxy/cost silently, then show cost summary formatted nicely."
Write-Host "[OK] Installed slash commands"

# Clear any permanent DeepSeek env vars (user should set per-session)
$envVarsToClear = @(
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_BASE_URL",
    "CLAUDE_CODE_SUBAGENT_MODEL"
)
foreach ($var in $envVarsToClear) {
    $current = [Environment]::GetEnvironmentVariable($var, "User")
    if ($current) {
        [Environment]::SetEnvironmentVariable($var, $null, "User")
        Write-Host "[OK] Cleared permanent env var: $var"
    }
}

# Create .env template if not exists
$envFile = "$env:USERPROFILE\.deepclaude-keys"
if (-not (Test-Path $envFile)) {
    @"
# DeepClaude API Keys
# Edit this file with your actual API keys

DEEPSEEK_API_KEY=sk-your-deepseek-key-here
# OPENROUTER_API_KEY=sk-or-your-key-here
# FIREWORKS_API_KEY=your-key-here
"@ | Set-Content $envFile
    Write-Host "[OK] Created $envFile - edit with your API keys"
} else {
    Write-Host "[OK] $envFile already exists"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Edit API keys:" -ForegroundColor Yellow
Write-Host "   notepad $env:USERPROFILE\.deepclaude-keys"
Write-Host ""
Write-Host "2. RESTART PowerShell" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Use commands:" -ForegroundColor Yellow
Write-Host "   start-deepclaude        # Start proxy + Claude with DeepSeek"
Write-Host "   start-deepclaude-vscode # Start proxy + VSCode with DeepSeek"
Write-Host "   claude-deepseek         # Claude with DeepSeek (proxy must be running)"
Write-Host "   claude-anthropic        # Claude with Anthropic (no proxy)"
Write-Host ""
Write-Host "Inside Claude Code, use slash commands:"
Write-Host "   /deepseek    /anthropic    /openrouter"
Write-Host "   /proxy-status    /proxy-cost"
Write-Host ""
