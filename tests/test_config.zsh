# Provider/model resolution and helpers.

resolve() {
  local -a reply
  _zta_resolve 2>&1 && print -r -- "${reply[*]}"
}

test_resolve_requires_a_key() {
  assert_contains "$(resolve)" "no API key set"
}

test_resolve_autodetects_gemini_first() {
  ZTA_GEMINI_API_KEY=g ZTA_OPENAI_API_KEY=o
  assert_eq "$(resolve)" "gemini gemini-3-flash-preview"
}

test_resolve_autodetects_openai() {
  ZTA_OPENAI_API_KEY=o
  assert_eq "$(resolve)" "openai gpt-4.1-mini"
}

test_resolve_autodetects_openrouter() {
  ZTA_OPENROUTER_API_KEY=r
  assert_eq "$(resolve)" "openrouter openai/gpt-oss-120b:nitro"
}

test_resolve_explicit_provider_and_model() {
  ZTA_GEMINI_API_KEY=g ZTA_OPENAI_API_KEY=o ZTA_PROVIDER=OpenAI ZTA_MODEL=gpt-5-mini
  assert_eq "$(resolve)" "openai gpt-5-mini"
}

test_resolve_or_prefix_forces_openrouter() {
  ZTA_GEMINI_API_KEY=g ZTA_OPENROUTER_API_KEY=r ZTA_PROVIDER=gemini ZTA_MODEL=or:qwen/qwen3.5-35b-a3b:nitro
  assert_eq "$(resolve)" "openrouter qwen/qwen3.5-35b-a3b:nitro"
}

test_resolve_missing_key_for_explicit_provider() {
  ZTA_PROVIDER=openrouter
  assert_contains "$(resolve)" "ZTA_OPENROUTER_API_KEY is not set"
}

test_resolve_local_openai_endpoint_needs_no_key() {
  ZTA_PROVIDER=openai ZTA_OPENAI_ENDPOINT=http://localhost:8080/v1/chat/completions ZTA_MODEL=local
  assert_eq "$(resolve)" "openai local"
}

test_resolve_unknown_provider() {
  ZTA_PROVIDER=claude ZTA_OPENAI_API_KEY=o
  assert_contains "$(resolve)" "unknown provider 'claude'"
}

test_is_true() {
  _zta_is_true true && _zta_is_true YES && _zta_is_true 1 || fail "true values"
  _zta_is_true false || _zta_is_true "" || _zta_is_true 0 && fail "false values"
  return 0
}

test_system_prompts_include_environment() {
  assert_contains "$(_zta_system_prompt short)" "exactly ONE single-line shell command"
  assert_contains "$(_zta_system_prompt long)" "Markdown"
  assert_contains "$(_zta_system_prompt short)" "OS type $OSTYPE"
}

test_system_prompt_override() {
  ZTA_SHORT_PROMPT="custom prompt"
  assert_contains "$(_zta_system_prompt short)" "custom prompt"
  assert_not_contains "$(_zta_system_prompt short)" "exactly ONE"
}
