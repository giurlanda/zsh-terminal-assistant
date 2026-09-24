# zta_request against the fake curl: request building, parsing and errors.

test_gemini_request() {
  ZTA_GEMINI_API_KEY=secret-gemini MOCK_RESPONSE=$FIXTURES/gemini.json
  assert_eq "$(zta_request short 'list files')" "ls -la"
  assert_eq "$(<$MOCK_DIR/url.txt)" \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"
  assert_contains "$(<$MOCK_DIR/config.txt)" 'header = "x-goog-api-key: secret-gemini"'
  assert_eq "$(jq -r '.contents[0].parts[0].text' $MOCK_DIR/request.json)" "list files"
  assert_contains "$(jq -r '.systemInstruction.parts[0].text' $MOCK_DIR/request.json)" "ONE single-line"
}

test_api_key_not_in_curl_arguments() {
  ZTA_GEMINI_API_KEY=secret-gemini MOCK_RESPONSE=$FIXTURES/gemini.json
  zta_request short 'list files' >/dev/null
  assert_not_contains "$(<$MOCK_DIR/args.txt)" "secret-gemini"
}

test_openai_responses_request() {
  ZTA_OPENAI_API_KEY=sk-test MOCK_RESPONSE=$FIXTURES/openai_responses.json
  assert_eq "$(zta_request short 'find logs')" "find . -name '*.log'"
  assert_eq "$(<$MOCK_DIR/url.txt)" "https://api.openai.com/v1/responses"
  assert_contains "$(<$MOCK_DIR/config.txt)" "Authorization: Bearer sk-test"
  assert_eq "$(jq -r '[.model, .input, .service_tier, .store] | join(",")' $MOCK_DIR/request.json)" \
    "gpt-4.1-mini,find logs,priority,false"
  assert_contains "$(jq -r .instructions $MOCK_DIR/request.json)" "ONE single-line"
}

test_openai_fast_disabled() {
  ZTA_OPENAI_API_KEY=sk-test ZTA_OPENAI_FAST=false MOCK_RESPONSE=$FIXTURES/openai_responses.json
  zta_request short 'x' >/dev/null
  assert_eq "$(jq -r '.service_tier // "none"' $MOCK_DIR/request.json)" "none"
}

test_openai_compatible_local_server() {
  ZTA_PROVIDER=openai ZTA_OPENAI_ENDPOINT=http://localhost:11434/v1/chat/completions
  ZTA_MODEL=LiquidAI/LFM2.5-1.2B-Thinking MOCK_RESPONSE=$FIXTURES/chat.json
  assert_eq "$(zta_request short 'disk usage')" "du -sh *"
  assert_eq "$(<$MOCK_DIR/url.txt)" "http://localhost:11434/v1/chat/completions"
  assert_not_contains "$(<$MOCK_DIR/config.txt)" "Authorization"
  assert_eq "$(jq -r '[.model, .messages[0].role, .messages[1].content, (.service_tier // "none")] | join(",")' \
    $MOCK_DIR/request.json)" "LiquidAI/LFM2.5-1.2B-Thinking,system,disk usage,none"
}

test_openrouter_request_via_prefix() {
  ZTA_OPENROUTER_API_KEY=or-key ZTA_MODEL=or:qwen/qwen3.5-35b-a3b:nitro MOCK_RESPONSE=$FIXTURES/chat.json
  assert_eq "$(zta_request long 'disk usage')" "du -sh *"
  assert_eq "$(<$MOCK_DIR/url.txt)" "https://openrouter.ai/api/v1/chat/completions"
  assert_contains "$(<$MOCK_DIR/config.txt)" "Authorization: Bearer or-key"
  assert_eq "$(jq -r .model $MOCK_DIR/request.json)" "qwen/qwen3.5-35b-a3b:nitro"
  assert_contains "$(jq -r '.messages[0].content' $MOCK_DIR/request.json)" "Markdown"
}

test_reasoning_blocks_are_stripped() {
  ZTA_OPENROUTER_API_KEY=k MOCK_RESPONSE=$FIXTURES/chat_think.json
  assert_eq "$(zta_request short 'free space')" "df -h"
}

test_api_error_message() {
  ZTA_OPENAI_API_KEY=bad MOCK_RESPONSE=$FIXTURES/error.json MOCK_HTTP_CODE=401
  local out
  out=$(zta_request short 'x' 2>&1) && fail "expected failure"
  assert_eq "$out" "zta: openai: Incorrect API key provided"
}

test_http_error_without_body() {
  ZTA_OPENAI_API_KEY=k MOCK_RESPONSE=/dev/null MOCK_HTTP_CODE=503
  local out
  out=$(zta_request short 'x' 2>&1) && fail "expected failure"
  assert_eq "$out" "zta: openai: HTTP 503"
}

test_transport_error() {
  ZTA_GEMINI_API_KEY=k MOCK_CURL_EXIT=28
  local out
  out=$(zta_request short 'x' 2>&1) && fail "expected failure"
  assert_eq "$out" "zta: request to gemini failed: (28) Operation timed out after 60000 milliseconds"
}

test_empty_answer() {
  ZTA_GEMINI_API_KEY=k MOCK_RESPONSE=$FIXTURES/empty.json
  local out
  out=$(zta_request short 'x' 2>&1) && fail "expected failure"
  assert_eq "$out" "zta: gemini returned an empty answer (model: gemini-3-flash-preview)"
}

test_missing_dependency() {
  ZTA_GEMINI_API_KEY=k
  path=($TEST_ROOT/tests/bin)
  rehash
  local out
  out=$(zta_request short 'x' 2>&1) && fail "expected failure"
  assert_eq "$out" "zta: 'jq' is required but not installed"
}

test_temporary_files_are_removed() {
  ZTA_GEMINI_API_KEY=k MOCK_RESPONSE=$FIXTURES/gemini.json
  local TMPDIR=$MOCK_DIR/tmp
  mkdir -p $TMPDIR
  zta_request short 'x' >/dev/null
  local -a dirs=($TMPDIR/zta.*(N))
  assert_eq "$#dirs" "0"
}

test_debug_keeps_temporary_files() {
  ZTA_GEMINI_API_KEY=k ZTA_DEBUG=true MOCK_RESPONSE=$FIXTURES/gemini.json
  local TMPDIR=$MOCK_DIR/tmp
  mkdir -p $TMPDIR
  zta_request short 'x' >/dev/null
  local -a dirs=($TMPDIR/zta.*(N))
  assert_eq "$#dirs" "1"
  [[ -s $dirs[1]/request.json && -s $dirs[1]/response.json ]] || fail "debug files missing"
}
