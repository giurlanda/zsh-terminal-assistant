# Markdown rendering for long mode.
# ZTA_RENDERER=auto (default) picks glow, then bat, then mdcat, then the
# built-in renderer. It can also be forced to glow|bat|mdcat|builtin|plain.

# Render Markdown read from stdin to the terminal.
_zta_render() {
  local renderer=${ZTA_RENDERER:-auto} bat_cmd=bat
  (( $+commands[bat] )) || bat_cmd=batcat   # Debian/Ubuntu package name

  if [[ $renderer == auto ]]; then
    if (( $+commands[glow] )); then
      renderer=glow
    elif (( $+commands[$bat_cmd] )); then
      renderer=bat
    elif (( $+commands[mdcat] )); then
      renderer=mdcat
    else
      renderer=builtin
    fi
  fi

  case $renderer in
    glow)
      (( $+commands[glow] )) || { _zta_render_builtin; return }
      glow --style auto --width "${COLUMNS:-80}" -
      ;;
    bat)
      (( $+commands[$bat_cmd] )) || { _zta_render_builtin; return }
      $bat_cmd --language markdown --style plain --paging never --color always
      ;;
    mdcat)
      (( $+commands[mdcat] )) || { _zta_render_builtin; return }
      mdcat -
      ;;
    plain)
      cat
      ;;
    *)
      _zta_render_builtin
      ;;
  esac
}

# Minimal dependency-free renderer (POSIX awk + ANSI colors): headings, bold,
# italic, inline code, fenced code blocks, lists, block quotes, links and rules.
_zta_render_builtin() {
  awk -v cols="${COLUMNS:-80}" '
    BEGIN {
      ESC = sprintf("%c", 27)
      R = ESC "[0m"; BOLD = ESC "[1m"; DIM = ESC "[2m"; ITALIC = ESC "[3m"; UL = ESC "[4m"
      H1 = ESC "[1;4;35m"; H2 = ESC "[1;35m"; H3 = ESC "[1;34m"
      CODE = ESC "[36m"; BULLET = ESC "[33m"
      in_code = 0
      width = cols > 0 && cols < 80 ? cols : 80
    }

    # Wrap every match of re in style, removing n marker chars on each side.
    function wrap(s, re, n, style,    out) {
      out = ""
      while (match(s, re)) {
        out = out substr(s, 1, RSTART - 1) style substr(s, RSTART + n, RLENGTH - 2 * n) R
        s = substr(s, RSTART + RLENGTH)
      }
      return out s
    }

    function links(s,    out, m, p) {
      out = ""
      while (match(s, /\[[^]]+\]\([^)]+\)/)) {
        m = substr(s, RSTART, RLENGTH)
        p = index(m, "](")
        out = out substr(s, 1, RSTART - 1) UL substr(m, 2, p - 2) R DIM " (" substr(m, p + 2, length(m) - p - 2) ")" R
        s = substr(s, RSTART + RLENGTH)
      }
      return out s
    }

    function emphasis(s) {
      s = wrap(s, "\\*\\*[^*]+\\*\\*", 2, BOLD)
      s = wrap(s, "__[^_]+__", 2, BOLD)
      s = wrap(s, "\\*[^* ][^*]*\\*", 1, ITALIC)
      return links(s)
    }

    # Inline formatting; code spans are extracted first so their content is left untouched.
    # RSTART/RLENGTH are global and emphasis() overwrites them: copy them first.
    function inline(s,    out, start, len) {
      out = ""
      while (match(s, /`[^`]+`/)) {
        start = RSTART; len = RLENGTH
        out = out emphasis(substr(s, 1, start - 1)) CODE substr(s, start + 1, len - 2) R
        s = substr(s, start + len)
      }
      return out emphasis(s)
    }

    # Apply style to a whole line, restoring it after every inline reset.
    function styled(s, style) {
      s = inline(s)
      gsub(ESC "\\[0m", R style, s)
      return style s R
    }

    /^[ \t]*(```|~~~)/ {
      in_code = !in_code
      next
    }

    in_code {
      print "    " CODE $0 R
      next
    }

    /^#+[ \t]/ {
      match($0, /^#+/)
      level = RLENGTH
      text = substr($0, level + 1)
      sub(/^[ \t]+/, "", text)
      print styled(text, level == 1 ? H1 : level == 2 ? H2 : H3)
      next
    }

    /^[ \t]*(---+|\*\*\*+|___+)[ \t]*$/ {
      line = ""
      for (i = 0; i < width; i++) line = line "─"
      print DIM line R
      next
    }

    /^[ \t]*>/ {
      text = $0
      sub(/^[ \t]*>[ \t]?/, "", text)
      print DIM "│ " R styled(text, ITALIC)
      next
    }

    /^[ \t]*[-*+][ \t]+/ {
      match($0, /^[ \t]*/)
      indent = substr($0, 1, RLENGTH)
      text = $0
      sub(/^[ \t]*[-*+][ \t]+/, "", text)
      print indent BULLET "•" R " " inline(text)
      next
    }

    { print inline($0) }
  '
}
