# OpenAI — Responses API by default, Chat Completions when the endpoint ends
# with /chat/completions (OpenAI-compatible servers: llama.cpp, LM Studio, Ollama...).
# Also hosts the Chat Completions helpers shared with OpenRouter.

_zta_openai_prepare() {
  local model=$1 system_prompt=$2 query=$3 body_file=$4
  url=${ZTA_OPENAI_ENDPOINT:-$ZTA_DEFAULT_OPENAI_ENDPOINT}
  headers=()
  [[ -n ${ZTA_OPENAI_API_KEY:-} ]] && headers+=("Authorization: Bearer $ZTA_OPENAI_API_KEY")

  # Fast mode = priority processing, only meaningful on the official API.
  local tier=""
  if _zta_is_true ${ZTA_OPENAI_FAST:-true} && ! _zta_openai_is_custom_endpoint openai; then
    tier=priority
  fi

  if [[ $url == */chat/completions ]]; then
    _zta_chat_body "$model" "$system_prompt" "$query" "$tier" >| "$body_file"
  else
    jq -n --arg model "$model" --arg system "$system_prompt" --arg query "$query" --arg tier "$tier" '
      {model: $model, instructions: $system, input: $query, store: false}
      + (if $tier != "" then {service_tier: $tier} else {} end)' >| "$body_file"
  fi
}

# Handles both Responses and Chat Completions payloads.
_zta_openai_parse() {
  jq -r 'if .choices then (.choices[0].message.content // "")
         else [.output[]? | select(.type == "message") | .content[]?
               | select(.type == "output_text") | .text] | join("")
         end' "$1"
}

# Print a Chat Completions request body. Usage: _zta_chat_body <model> <system> <query> [service_tier]
_zta_chat_body() {
  jq -n --arg model "$1" --arg system "$2" --arg query "$3" --arg tier "${4:-}" '
    {model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $query}]}
    + (if $tier != "" then {service_tier: $tier} else {} end)'
}

_zta_chat_parse() {
  jq -r '.choices[0].message.content // ""' "$1"
}
