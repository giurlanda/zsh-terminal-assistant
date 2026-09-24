# Google Gemini — generateContent API.

_zta_gemini_prepare() {
  local model=$1 system_prompt=$2 query=$3 body_file=$4
  url="https://generativelanguage.googleapis.com/v1beta/models/${model#models/}:generateContent"
  headers=("x-goog-api-key: $ZTA_GEMINI_API_KEY")
  jq -n --arg system "$system_prompt" --arg query "$query" '{
    systemInstruction: {parts: [{text: $system}]},
    contents: [{role: "user", parts: [{text: $query}]}]
  }' >| "$body_file"
}

_zta_gemini_parse() {
  jq -r '[.candidates[0].content.parts[]? | select(.thought != true) | .text // empty] | join("")' "$1"
}
