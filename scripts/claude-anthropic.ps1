# Claude with Anthropic (direct, no proxy)

# Clear DeepSeek env vars for this session
$env:ANTHROPIC_AUTH_TOKEN = $null
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $null
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $null
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $null
$env:ANTHROPIC_BASE_URL = $null
$env:CLAUDE_CODE_SUBAGENT_MODEL = $null

claude @args
