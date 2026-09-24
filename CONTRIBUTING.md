# Contributing

## Layout

```
zsh-terminal-assistant.plugin.zsh   entry point (loaded by zplug and friends)
lib/config.zsh                      defaults, provider/model resolution, key bindings
lib/prompts.zsh                     system prompts
lib/http.zsh                        curl transport and zta_request
lib/providers/*.zsh                 request body and response parsing per provider
lib/render.zsh                      Markdown renderers
lib/widgets.zsh                     ZLE widgets
tests/run.zsh                       unit tests (tests/test_*.zsh)
tests/widgets_test.py               widget tests in a pseudo-terminal
tests/bin/curl                      fake curl used by both suites
```

## Adding a provider

Create `lib/providers/<name>.zsh` with two functions and source it from the
entry point:

- `_zta_<name>_prepare <model> <system_prompt> <query> <body_file>`: writes
  the JSON body and sets the caller's `url` and `headers` variables.
- `_zta_<name>_parse <response_file>`: prints the answer text.

Then extend `_zta_resolve` in `lib/config.zsh` (default model and key variable)
and add tests to `tests/test_request.zsh`.

## Running the tests

```sh
zsh tests/run.zsh [filter]
python3 tests/widgets_test.py [filter]

# with other plugins loaded after this one
ZTA_TEST_PLUGINS=/path/zsh-autosuggestions.zsh:/path/zsh-syntax-highlighting.zsh \
  python3 tests/widgets_test.py
```

No network access or API key is needed: `tests/bin/curl` replaces curl and
answers with the fixtures in `tests/fixtures`.

## Manual checklist

Before a release, check these with a real provider in a real terminal:

- [ ] Ctrl+G: the request disappears, ⏳ is shown, the suggestion appears in cyan with the hint below
- [ ] Enter accepts: normal colors, hint gone, command not executed
- [ ] Any other key, including arrows and Ctrl+C, restores the original request
- [ ] Ctrl+C / Esc while waiting cancel the request and restore the line
- [ ] Ctrl+B: the answer is rendered below the question, then an empty prompt follows
- [ ] Errors (wrong key, no network) show a one-line message below the prompt
- [ ] Emacs and vi keymaps
