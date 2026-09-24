# OpenRouter — OpenAI-compatible Chat Completions API.

_zta_openrouter_prepare() {
  local model=$1 system_prompt=$2 query=$3 body_file=$4
  url="https://openrouter.ai/api/v1/chat/completions"
  headers=(
    "Authorization: Bearer $ZTA_OPENROUTER_API_KEY"
    "HTTP-Referer: https://github.com/giurlanda/zsh-terminal-assistant"
    "X-Title: zsh-terminal-assistant"
  )
  _zta_chat_body "$model" "$system_prompt" "$query" >| "$body_file"
}

_zta_openrouter_parse() {
  _zta_chat_parse "$1"
}
