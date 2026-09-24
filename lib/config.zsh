# Configuration defaults and provider/model resolution.
#
# Every setting is read at call time (not at load time), so `export ZTA_MODEL=...`
# takes effect immediately. The only exception are the hotkeys, which are bound
# when the plugin is loaded.

typeset -g ZTA_VERSION="0.1.0"

typeset -g ZTA_DEFAULT_GEMINI_MODEL="gemini-3-flash-preview"
typeset -g ZTA_DEFAULT_OPENAI_MODEL="gpt-4.1-mini"
typeset -g ZTA_DEFAULT_OPENROUTER_MODEL="openai/gpt-oss-120b:nitro"
typeset -g ZTA_DEFAULT_OPENAI_ENDPOINT="https://api.openai.com/v1/responses"

: ${ZTA_SHORT_HOTKEY='^g'}
: ${ZTA_LONG_HOTKEY='^b'}

# Print an error message on stderr, prefixed with the plugin name.
_zta_error() {
  print -r -- "zta: $*" >&2
}

# Return 0 if the value of a boolean setting is true (true/1/yes/on).
_zta_is_true() {
  [[ ${(L)1} == (true|1|yes|on) ]]
}

# Check that the runtime dependencies are available.
_zta_check_deps() {
  local cmd
  for cmd in curl jq; do
    if (( ! $+commands[$cmd] )); then
      _zta_error "'$cmd' is required but not installed"
      return 1
    fi
  done
}

# Resolve provider and model from the environment.
# On success sets reply=(provider model) and returns 0.
_zta_resolve() {
  local provider=${ZTA_PROVIDER:-} model=${ZTA_MODEL:-}

  # The `or:` model prefix forces OpenRouter and is stripped from the model.
  if [[ $model == or:* ]]; then
    provider=openrouter
    model=${model#or:}
  fi

  if [[ -z $provider ]]; then
    if [[ -n ${ZTA_GEMINI_API_KEY:-} ]]; then
      provider=gemini
    elif [[ -n ${ZTA_OPENAI_API_KEY:-} ]]; then
      provider=openai
    elif [[ -n ${ZTA_OPENROUTER_API_KEY:-} ]]; then
      provider=openrouter
    else
      _zta_error "no API key set (ZTA_GEMINI_API_KEY, ZTA_OPENAI_API_KEY or ZTA_OPENROUTER_API_KEY)"
      return 1
    fi
  fi

  provider=${(L)provider}
  case $provider in
    gemini)     : ${model:=$ZTA_DEFAULT_GEMINI_MODEL} ;;
    openai)     : ${model:=$ZTA_DEFAULT_OPENAI_MODEL} ;;
    openrouter) : ${model:=$ZTA_DEFAULT_OPENROUTER_MODEL} ;;
    *)
      _zta_error "unknown provider '$provider' (expected gemini, openai or openrouter)"
      return 1
      ;;
  esac

  # A key is mandatory, except for OpenAI-compatible local servers.
  local key_var="ZTA_${(U)provider}_API_KEY"
  if [[ -z ${(P)key_var:-} ]] && ! _zta_openai_is_custom_endpoint $provider; then
    _zta_error "$key_var is not set"
    return 1
  fi

  reply=($provider $model)
}

# Return 0 if the provider is OpenAI pointed at a non-OpenAI endpoint.
_zta_openai_is_custom_endpoint() {
  [[ $1 == openai && ${ZTA_OPENAI_ENDPOINT:-$ZTA_DEFAULT_OPENAI_ENDPOINT} != https://api.openai.com/* ]]
}

# Bind the widgets to the configured hotkeys (an empty hotkey disables it).
_zta_bind_keys() {
  local keymap
  for keymap in emacs viins vicmd; do
    [[ -n $ZTA_SHORT_HOTKEY ]] && bindkey -M $keymap "$ZTA_SHORT_HOTKEY" zta-short-widget
    [[ -n $ZTA_LONG_HOTKEY ]] && bindkey -M $keymap "$ZTA_LONG_HOTKEY" zta-long-widget
  done
  return 0
}
