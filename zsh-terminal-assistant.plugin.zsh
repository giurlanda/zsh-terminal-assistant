# zsh-terminal-assistant — use an LLM directly from the zsh command line.
# https://github.com/giurlanda/zsh-terminal-assistant
#
# Short mode (default Ctrl+G): natural language -> single shell command to approve.
# Long mode  (default Ctrl+B): natural language -> concise Markdown answer.

# Standardized $0 handling (zsh plugin standard).
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

typeset -g ZTA_ROOT="${0:A:h}"

source "$ZTA_ROOT/lib/config.zsh"
source "$ZTA_ROOT/lib/prompts.zsh"
source "$ZTA_ROOT/lib/http.zsh"
source "$ZTA_ROOT/lib/providers/gemini.zsh"
source "$ZTA_ROOT/lib/providers/openai.zsh"
source "$ZTA_ROOT/lib/providers/openrouter.zsh"
source "$ZTA_ROOT/lib/render.zsh"
source "$ZTA_ROOT/lib/widgets.zsh"

# Widgets and key bindings only make sense in an interactive shell with ZLE.
if [[ -o interactive ]]; then
  zle -N zta-short-widget
  zle -N zta-long-widget
  _zta_bind_keys
fi
