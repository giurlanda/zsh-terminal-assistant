# Markdown rendering and command-line helpers.

test_builtin_renderer() {
  local out=$(COLUMNS=40 _zta_render_builtin <$FIXTURES/long.md | strip_ansi)
  assert_contains "$out" $'Title\nSome bold, italic and code with a link (https://example.com).'
  assert_contains "$out" $'Section\n• item one\n  • nested x'
  assert_contains "$out" "│ a quote"
  assert_contains "$out" "────────────────────────────────────────"
  assert_not_contains "$out" "─────────────────────────────────────────"
  assert_contains "$out" '    echo "**not bold**"'
  assert_not_contains "$out" '```'
}

test_builtin_renderer_colors() {
  local out=$(print -r -- 'a **b** `c`' | _zta_render_builtin)
  assert_eq "$out" $'a \e[1mb\e[0m \e[36mc\e[0m'
}

test_renderer_plain_passthrough() {
  ZTA_RENDERER=plain
  assert_eq "$(_zta_render <$FIXTURES/long.md)" "$(<$FIXTURES/long.md)"
}

test_forced_renderer_falls_back_to_builtin() {
  ZTA_RENDERER=glow
  path=($TEST_ROOT/tests/bin /usr/bin /bin)
  rehash
  (( $+commands[glow] )) && return 0
  assert_contains "$(print '# Hi' | _zta_render)" $'\e[1;4;35mHi'
}

test_query_from_buffer() {
  local REPLY
  _zta_query_from_buffer "# lista file  "; assert_eq "$REPLY" "lista file"
  _zta_query_from_buffer "  ## find big files"; assert_eq "$REPLY" "find big files"
  _zta_query_from_buffer "no hash here"; assert_eq "$REPLY" "no hash here"
  _zta_query_from_buffer "#   "; assert_eq "$REPLY" ""
}

test_clean_command() {
  assert_eq "$(_zta_clean_command 'ls -la')" "ls -la"
  assert_eq "$(_zta_clean_command $'\n  ls -la  \n')" "ls -la"
  assert_eq "$(_zta_clean_command $'```bash\nfind . -name "*.py"\n```')" 'find . -name "*.py"'
  assert_eq "$(_zta_clean_command $'Here you go:\n```\ndu -sh *\n```\nExplanation')" "du -sh *"
  assert_eq "$(_zta_clean_command '`pwd`')" "pwd"
  assert_eq "$(_zta_clean_command '$ echo hi')" "echo hi"
  _zta_clean_command $'\n \n' && fail "blank answer must fail"
  return 0
}
