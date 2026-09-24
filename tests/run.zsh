#!/usr/bin/env zsh
# Test runner: sources tests/test_*.zsh and runs every test_* function in an
# isolated subshell. Usage: zsh tests/run.zsh [name-pattern]

emulate -R zsh
setopt extendedglob

typeset -g TEST_ROOT=${0:A:h:h}
typeset -g FIXTURES=$TEST_ROOT/tests/fixtures

# Assertions print a message and exit the test subshell on failure.
fail() {
  print -r -- "    $*" >&2
  exit 1
}

assert_eq() {
  [[ $1 == $2 ]] || fail "${3:-assert_eq}: expected [$2], got [$1]"
}

assert_contains() {
  [[ $1 == *$2* ]] || fail "${3:-assert_contains}: [$1] does not contain [$2]"
}

assert_not_contains() {
  [[ $1 != *$2* ]] || fail "${3:-assert_not_contains}: [$1] contains [$2]"
}

# Remove ANSI escape sequences.
strip_ansi() {
  sed $'s/\x1b\\[[0-9;]*m//g'
}

# Fresh plugin environment with the fake curl first in PATH.
setup() {
  unset -m 'ZTA_*'
  source $TEST_ROOT/zsh-terminal-assistant.plugin.zsh || exit 1
  path=($TEST_ROOT/tests/bin $path)
  rehash
  export MOCK_RESPONSE MOCK_HTTP_CODE MOCK_CURL_EXIT MOCK_DELAY
}

for file in $TEST_ROOT/tests/test_*.zsh; do
  source $file
done

typeset -i passed=0 failed=0
for name in ${(ok)functions[(I)test_*]}; do
  [[ -n $1 && $name != *$1* ]] && continue
  export MOCK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/zta-test.XXXXXX")
  if ( setup; $name ); then
    (( passed++ ))
    print -r -- "ok   $name"
  else
    (( failed++ ))
    print -r -- "FAIL $name"
  fi
  rm -rf -- $MOCK_DIR
done

print -r -- ""
print -r -- "$passed passed, $failed failed"
(( failed == 0 ))
