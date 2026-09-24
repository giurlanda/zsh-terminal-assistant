# HTTP transport and the request pipeline shared by all providers.
#
# Each provider implements two functions:
#   _zta_<provider>_prepare <model> <system_prompt> <query> <body_file>
#       writes the JSON request body and sets `url` and `headers` (caller's locals)
#   _zta_<provider>_parse <response_file>
#       prints the answer text extracted from the JSON response

# POST a JSON file and print the HTTP status code.
# Usage: _zta_http_post <url> <body_file> <response_file> [header...]
# Headers go through a curl config read from a file descriptor, so API keys
# never appear in the process list.
_zta_http_post() {
  local url=$1 body_file=$2 response_file=$3
  shift 3
  local header
  local -a config=()
  for header in "$@"; do
    header=${header//\\/\\\\}
    config+=("header = \"${header//\"/\\\"}\"")
  done
  curl --silent --show-error --max-time "${ZTA_TIMEOUT:-60}" \
    --request POST --header 'Content-Type: application/json' \
    --config <(print -rl -- $config) \
    --data-binary "@$body_file" --output "$response_file" \
    --write-out '%{http_code}' -- "$url"
}

# Print the error message contained in an API error response, if any.
_zta_api_error() {
  jq -r '(if type == "array" then .[0] else . end)
         | (.error.message? // .error? // .message? // empty)
         | if type == "string" then . else tojson end' "$1" 2>/dev/null \
    || head -c 200 -- "$1" 2>/dev/null
}

# Remove reasoning blocks (<think>...</think>) emitted by some local models.
_zta_strip_reasoning() {
  emulate -L zsh
  setopt extendedglob
  local text=$1
  text=${text//\<think\>*\<\/think\>/}
  print -r -- "${text##[[:space:]]#}"
}

# Send a query to the configured LLM and print the answer on stdout.
# Usage: zta_request <short|long> <query> [workdir]
# Errors are printed on stderr (one line, prefixed with "zta:").
zta_request() {
  emulate -L zsh
  setopt extendedglob

  local mode=$1 query=$2 workdir=${3:-}
  local -a reply
  _zta_check_deps || return 1
  _zta_resolve || return 1
  local provider=$reply[1] model=$reply[2]

  local system_prompt
  system_prompt=$(_zta_system_prompt $mode) || return 1

  local cleanup=0
  if [[ -z $workdir ]]; then
    workdir=$(mktemp -d "${TMPDIR:-/tmp}/zta.XXXXXX") || return 1
    _zta_is_true ${ZTA_DEBUG:-false} || cleanup=1
  fi

  {
    local url http_code text
    local -a headers
    _zta_${provider}_prepare "$model" "$system_prompt" "$query" "$workdir/request.json" || return 1

    if ! http_code=$(_zta_http_post "$url" "$workdir/request.json" "$workdir/response.json" \
                       "${headers[@]}" 2>"$workdir/curl.err"); then
      local curl_error=$(<"$workdir/curl.err")
      _zta_error "request to $provider failed: ${${curl_error#curl: }:-unknown error}"
      return 1
    fi

    if [[ $http_code != 2<-> ]]; then
      local api_error=$(_zta_api_error "$workdir/response.json")
      _zta_error "$provider: ${${api_error%%$'\n'*}:-HTTP $http_code}"
      return 1
    fi

    text=$(_zta_${provider}_parse "$workdir/response.json")
    text=$(_zta_strip_reasoning "$text")
    if [[ -z ${text//[[:space:]]/} ]]; then
      _zta_error "$provider returned an empty answer (model: $model)"
      return 1
    fi
    print -r -- "$text"
  } always {
    (( cleanup )) && rm -rf -- "$workdir"
  }
}
