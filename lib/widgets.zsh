# ZLE widgets: zta-short-widget (command suggestion) and zta-long-widget (Markdown answer).

typeset -ga ZTA_SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
typeset -g ZTA_ACCEPT_HINT='▶ Enter = accept  |  Any other key = restore'

# Extract the natural language request from the command line: strip the
# leading "#" markers and surrounding whitespace. Result in REPLY.
_zta_query_from_buffer() {
  emulate -L zsh
  setopt extendedglob
  REPLY=${${1##[[:space:]\#]#}%%[[:space:]]#}
}

# Reduce a model answer to a single command line: take the first fenced code
# block if present, then the first non-empty line, without prompt symbol or
# surrounding backticks.
_zta_clean_command() {
  emulate -L zsh
  setopt extendedglob
  local text=$1 line
  if [[ $text == *'```'* ]]; then
    text=${text#*'```'}
    [[ $text == *$'\n'* ]] && text=${text#*$'\n'}
    text=${text%%'```'*}
  fi
  for line in ${(f)text}; do
    line=${${line##[[:space:]]#}%%[[:space:]]#}
    [[ -z $line ]] && continue
    line=${line#'$ '}
    [[ $line == '`'*'`' ]] && line=${${line#'`'}%'`'}
    print -r -- "$line"
    return 0
  done
  return 1
}

# Kill a process and all its descendants.
_zta_kill_tree() {
  local child
  for child in ${(f)"$(pgrep -P $1 2>/dev/null)"}; do
    _zta_kill_tree $child
  done
  kill $1 2>/dev/null
}

# Read one key press into REPLY, including the rest of an escape sequence
# (arrow keys, ...), so nothing leaks into the command line. Ctrl+C (SIGINT)
# is returned as $'\x03'. With a timeout in seconds, return 1 if no key arrives.
_zta_read_key() {
  setopt localtraps
  local timeout=${1:-} key
  local -i interrupted=0
  trap 'interrupted=1' INT
  while :; do
    if read -t ${timeout:-0.1} -k 1 key; then
      REPLY=$key
      # ESC [ params final / ESC O final / ESC key (Alt+key).
      if [[ $key == $'\e' ]] && read -t 0.02 -k 1 key; then
        REPLY+=$key
        if [[ $key == ('['|O) ]]; then
          while read -t 0.02 -k 1 key; do
            REPLY+=$key
            [[ $key == [@-~] ]] && break
          done
        fi
      fi
      return 0
    fi
    if (( interrupted )); then
      REPLY=$'\x03'
      return 0
    fi
    [[ -n $timeout ]] && return 1
  done
}

# Run zta_request in the background while showing the spinner.
# Status 0: REPLY is the answer. Status 1: REPLY is the error message.
# Status 2: the user cancelled (Ctrl+C or Esc).
_zta_run() {
  setopt localtraps
  local mode=$1 query=$2 workdir pid
  local -i frame=0 cancelled=1 interrupted=0
  # Ctrl+C arrives as SIGINT: handle it as a cancel instead of aborting the line.
  trap 'interrupted=1' INT

  workdir=$(mktemp -d "${TMPDIR:-/tmp}/zta.XXXXXX") || {
    REPLY="zta: cannot create a temporary directory"
    return 1
  }

  {
    { zta_request $mode "$query" "$workdir" >"$workdir/answer" 2>"$workdir/error"
      : >"$workdir/done" } &!
    pid=$!

    # Hide the cursor, otherwise it sits on the spinner (the buffer is empty).
    echoti civis 2>/dev/null
    while [[ ! -e $workdir/done ]] && kill -0 $pid 2>/dev/null; do
      POSTDISPLAY="${ZTA_SPINNER_FRAMES[frame % $#ZTA_SPINNER_FRAMES + 1]}"
      region_highlight=("0 $#POSTDISPLAY fg=yellow")
      zle -R
      (( frame++ ))
      # Wait ~100ms for a key: Ctrl+C / Esc cancel, anything else is discarded.
      if _zta_read_key 0.1 && [[ $REPLY == ($'\x03'|$'\e') ]] || (( interrupted )); then
        return 2
      fi
    done
    cancelled=0

    if [[ -s $workdir/answer ]]; then
      REPLY=$(<"$workdir/answer")
      return 0
    fi
    REPLY=$(<"$workdir/error")
    REPLY=${${REPLY%%$'\n'*}:-"zta: the request was aborted"}
    return 1
  } always {
    # Also reached when the widget is interrupted by SIGINT.
    echoti cnorm 2>/dev/null
    (( cancelled )) && [[ -n $pid ]] && _zta_kill_tree $pid
    _zta_is_true ${ZTA_DEBUG:-false} || rm -rf -- "$workdir"
  }
}

# Short mode: replace the request with a single command to approve.
zta-short-widget() {
  emulate -L zsh
  local orig=$BUFFER query REPLY cmd
  local -i rc

  _zta_query_from_buffer "$orig"
  query=$REPLY
  if [[ -z $query ]]; then
    zle -M "zta: type a request first, e.g. '# list files'"
    return 1
  fi

  {
    BUFFER= CURSOR=0
    _zta_run short "$query"
    rc=$?
    POSTDISPLAY= region_highlight=()

    if (( rc == 0 )); then
      _zta_is_true ${ZTA_HISTORY:-false} && print -rs -- "$orig"
      cmd=$(_zta_clean_command "$REPLY") || { rc=1; REPLY="zta: the model returned no command" }
    fi
    if (( rc != 0 )); then
      BUFFER=$orig CURSOR=$#orig
      (( rc == 1 )) && zle -M "$REPLY"
      return 1
    fi

    # Show the suggestion in cyan with the approval hint below it.
    BUFFER=$cmd CURSOR=$#cmd
    POSTDISPLAY=$'\n'$ZTA_ACCEPT_HINT
    region_highlight=("0 $#BUFFER fg=cyan" "$#BUFFER $(( $#BUFFER + $#POSTDISPLAY )) fg=8")
    zle -R

    _zta_read_key
    if [[ $REPLY == ($'\r'|$'\n') ]]; then
      CURSOR=$#BUFFER
    else
      BUFFER=$orig CURSOR=$#orig
    fi
  } always {
    POSTDISPLAY= region_highlight=()
  }
}

# Long mode: print a Markdown-rendered answer above a fresh prompt.
zta-long-widget() {
  emulate -L zsh
  local orig=$BUFFER query REPLY
  local -i rc

  _zta_query_from_buffer "$orig"
  query=$REPLY
  if [[ -z $query ]]; then
    zle -M "zta: type a question first, e.g. '# how does find -exec work?'"
    return 1
  fi

  {
    BUFFER= CURSOR=0
    _zta_run long "$query"
    rc=$?
    POSTDISPLAY= region_highlight=()
    BUFFER=$orig CURSOR=$#orig

    if (( rc != 0 )); then
      (( rc == 1 )) && zle -M "$REPLY"
      return 1
    fi
    _zta_is_true ${ZTA_HISTORY:-false} && print -rs -- "$orig"

    # Leave the question on screen, print the answer below it, then redraw
    # an empty prompt.
    zle -R
    zle -I
    print
    _zta_render <<<"$REPLY"
    BUFFER= CURSOR=0
  } always {
    POSTDISPLAY= region_highlight=()
  }
}
