# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**DeepClaude** routes Claude Code's Anthropic API calls to cheaper Anthropic-compatible backends (DeepSeek V4 Pro, OpenRouter, Fireworks AI). It does NOT modify Claude Code itself — it overrides environment variables that Claude Code reads to determine its API endpoint.

## Architecture

### Direct mode (no proxy)
```
deepclaude.sh/ps1
  → sets ANTHROPIC_BASE_URL = backend URL (e.g. api.deepseek.com/anthropic)
  → sets ANTHROPIC_AUTH_TOKEN = API key
  → sets model env vars (ANTHROPIC_DEFAULT_OPUS_MODEL → deepseek-v4-pro, etc.)
  → exec claude
```

### Remote mode (`--remote`)
```
deepclaude.sh/ps1 --remote
  → starts proxy/start-proxy.js on localhost:3200
  → sets ANTHROPIC_BASE_URL = http://127.0.0.1:3200
  → exec claude remote-control
```
Remote control needs Anthropic for the bridge WebSocket, but model calls go through the proxy to DeepSeek.

### Proxy (`--mode` standalone, used for live switching)
```
node proxy/start-proxy.js --mode deepseek
  → HTTP server on localhost:3200
  → /v1/messages → active backend (DeepSeek/OpenRouter/Anthropic)
  → /_proxy/mode POST → switch backend mid-session
  → /_proxy/status GET → current mode + uptime
  → /_proxy/cost GET → token tracking + cost comparison
  → everything else → passthrough to api.anthropic.com
```

## Key files

| File | Purpose |
|---|---|
| `deepclaude.sh` | macOS/Linux launcher (bash) |
| `deepclaude.ps1` | Windows launcher (PowerShell) |
| `proxy/start-proxy.js` | CLI entry point — detects legacy vs standalone mode |
| `proxy/model-proxy.js` | Core proxy — HTTP server, routing, model remap, thinking strip, usage normalizer, cost tracking |

## No dependencies

The proxy uses only Node.js built-ins (`http`, `https`, `url`, `stream`). Zero npm packages. Uses ESM (`import`/`export`). For Node.js < 22, a `package.json` with `{ "type": "module" }` is needed.

## Branch structure

- **`main`** — tracks upstream (Ali Attaran). Do NOT commit directly here. Merge upstream updates into windows-fixes.
- **`windows-fixes`** — active development branch with platform-specific and multi-turn thinking fixes:
  1. `67e2126` — Proxy arg detection: PowerShell strips `""` args, causing `--mode` to be parsed as targetUrl. Fix: detect legacy mode by checking if first positional arg contains `://`.
  2. `58176dc` — Delete top-level `thinking` param when stripping all blocks (DeepSeek rejects requests where thinking blocks are gone but thinking mode is still enabled → 400).
  3. `e5301ae` — Same-backend multi-turn thinking: when no switch has occurred, use `stripUnsignedThinkingBlocks` (keep signed blocks from current backend) instead of `stripAllThinkingBlocks`. DeepSeek requires its own thinking blocks to be passed back for multi-turn context.

**Workflow**: `git checkout main && git pull origin main && git checkout windows-fixes && git merge main`

## Model remapping

The `MODEL_REMAP` table in `model-proxy.js` maps Anthropic model names to backend equivalents:
- `claude-opus-4-6/4-7` → `deepseek-v4-pro`
- `claude-sonnet-4-6` → `deepseek-v4-flash`
- `claude-haiku-4-5` → `deepseek-v4-flash`

This happens transparently in the proxy during `/v1/messages` routing.

## Thinking block stripping (critical logic)

Two functions in `model-proxy.js`:

- **`stripAllThinkingBlocks`**: Removes ALL `type: "thinking"` content blocks from messages AND deletes the top-level `thinking` parameter.
- **`stripUnsignedThinkingBlocks`**: Removes only thinking blocks that lack a `signature` field (keeps signed blocks from the current backend).

Decision tree (in request handler):
- **Anthropic mode**: `hadNonAnthropicSession` ? `stripAll` : `stripUnsigned`
- **Non-Anthropic mode**: `hadSwitch` ? `stripAll` : `stripUnsigned`

Two state flags: `hadNonAnthropicSession` and `hadSwitch`. These can be reset via `/_proxy/reset` endpoint or by restarting the proxy.

## Usage normalization

DeepSeek/OpenRouter sometimes omit `usage` fields in streaming responses, crashing Claude Code. The `UsageNormalizer` Transform stream injects `{ input_tokens: 0, output_tokens: 0 }` into `message_start` and `message_delta` SSE events when missing. `normalizeJsonBody` does the same for non-streaming JSON responses.

## Common commands

```bash
# Start proxy standalone (tests)
node proxy/start-proxy.js --mode deepseek

# Start proxy standalone with custom port
node proxy/start-proxy.js --mode deepseek --port 3201

# Check proxy status (includes flags for debugging)
curl -s http://127.0.0.1:3200/_proxy/status
# Returns: {"mode":"deepseek","uptime":123,"requests":5,"flags":{"hadSwitch":false,"hadNonAnthropicSession":true}}

# Switch backend mid-session
curl -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=anthropic

# Reset state flags (fixes thinking block errors after switching)
curl -sX POST http://127.0.0.1:3200/_proxy/reset

# Cost tracking
curl -s http://127.0.0.1:3200/_proxy/cost

# Launch directly (bypass proxy)
./deepclaude.sh --backend deepseek
./deepclaude.ps1 -b or

# Remote control mode
./deepclaude.sh --remote -b deepseek
```

## Linux deployment (systemd)

Service file at `/etc/systemd/system/deepclaude-proxy.service`:
```
[Service]
User=<user>
WorkingDirectory=/home/<user>/deepclaude
Environment="DEEPSEEK_API_KEY=sk-..."
ExecStart=/usr/bin/node proxy/start-proxy.js --mode deepseek
Restart=always
```

Manage with `systemctl start|stop|restart|status deepclaude-proxy`. Logs: `journalctl -u deepclaude-proxy -f`.

Slash commands at `~/.claude/commands/{deepseek,anthropic}.md`:
```
Run curl -sX POST http://127.0.0.1:3200/_proxy/reset && curl -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=deepseek silently, then just say in 3 words: Switched to DeepSeek.
```

**Best practice for switching:** Always reset state before switching to avoid thinking block errors:
```bash
curl -sX POST http://127.0.0.1:3200/_proxy/reset
curl -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=deepseek
```

## Windows deployment

Proxy via background process: `Start-Process -WindowStyle Hidden -FilePath node -ArgumentList "proxy\start-proxy.js", "--mode", "deepseek"`.

Use `curl.exe` not `curl` (PowerShell alias). Use `Set-Content` for slash commands, not here-strings. `setx` writes registry but doesn't affect current session — also set `$env:DEEPSEEK_API_KEY` for the running session.

**Windows slash commands** (must use `curl.exe`):
```powershell
# Create deepseek.md
Set-Content "$env:USERPROFILE\.claude\commands\deepseek.md" "Run curl.exe -sX POST http://127.0.0.1:3200/_proxy/reset; curl.exe -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=deepseek silently, then just say in 3 words: Switched to DeepSeek."

# Create anthropic.md
Set-Content "$env:USERPROFILE\.claude\commands\anthropic.md" "Run curl.exe -sX POST http://127.0.0.1:3200/_proxy/reset; curl.exe -sX POST http://127.0.0.1:3200/_proxy/mode -d backend=anthropic silently, then just say in 3 words: Switched to Anthropic."
```

**Windows common commands:**
```powershell
# Check status
curl.exe -s http://127.0.0.1:3200/_proxy/status

# Switch with reset (recommended)
curl.exe -sX POST http://127.0.0.1:3200/_proxy/reset; curl.exe -sX POST http://127.0.0.1:3200/_proxy/mode -d "backend=deepseek"

# Or use PowerShell native (when curl.exe not available)
Invoke-WebRequest -Uri "http://127.0.0.1:3200/_proxy/reset" -Method POST
Invoke-WebRequest -Uri "http://127.0.0.1:3200/_proxy/mode" -Method POST -Body "backend=deepseek"
```

## Route path handling

`MODEL_PATHS = ['/v1/messages']` — uses exact path matching. Path overlap logic strips shared prefixes between the target URL pathname and the client URL (prevents `/api/v1/v1/messages` double-prefix on OpenRouter).

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `400 content[].thinking must be passed back` | `hadSwitch=true` after switching backends | `curl -sX POST http://127.0.0.1:3200/_proxy/reset` then start new conversation |
| `401 Invalid bearer token` (Anthropic mode) | Auth token issue | `claude logout && claude login`, or restart proxy with `--mode deepseek` |
| `401 Invalid bearer token` (DeepSeek mode) | `DEEPSEEK_API_KEY` not set | Set env var and restart proxy |
| Bash syntax error on Windows | Claude using Bash instead of PowerShell | Add to CLAUDE.md: "Use PowerShell syntax, not Bash" |

**Debug steps:**
```bash
# 1. Check proxy status and flags
curl -s http://127.0.0.1:3200/_proxy/status | jq

# 2. If hadSwitch=true and getting 400 errors:
curl -sX POST http://127.0.0.1:3200/_proxy/reset

# 3. If still broken, restart proxy:
# Stop with Ctrl+C, then:
node proxy/start-proxy.js --mode deepseek --port 3200
```

## Security notes

- `/_proxy/mode` and `/_proxy/reset` POST are CSRF-protected (only allows `127.0.0.1`/`localhost` origin)
- Control endpoints have 1KB body size limit
- Proxy puts all listening on `127.0.0.1` only — never exposed to network
