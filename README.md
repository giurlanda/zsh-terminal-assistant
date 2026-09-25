# zsh-terminal-assistant

[![CI](https://github.com/giurlanda/zsh-terminal-assistant/actions/workflows/ci.yml/badge.svg)](https://github.com/giurlanda/zsh-terminal-assistant/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/giurlanda/zsh-terminal-assistant?label=release&sort=semver)](https://github.com/giurlanda/zsh-terminal-assistant/tags)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![zsh ≥ 5.8](https://img.shields.io/badge/zsh-%E2%89%A5%205.8-4EAA25?logo=gnubash&logoColor=white)](https://www.zsh.org/)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)](#requirements)

Use an LLM directly from your zsh command line. Describe what you want in plain
language, press a hotkey, and get either a ready-to-approve shell command or a
concise Markdown answer rendered in the terminal.

Works with **Google Gemini**, **OpenAI**, **OpenRouter** and any
**OpenAI-compatible server** (llama.cpp, LM Studio, Ollama, …).

## How it works

### Short mode: get a command (`Ctrl+G`)

```text
❯ # list files sorted by size        ← type a request, press Ctrl+G
❯ ⠹                                  ← the request disappears while waiting
❯ ls -lhS                            ← the suggestion is shown in cyan
▶ Enter = accept  |  Any other key = restore
```

- **Enter** accepts the command: it becomes a normal command line that you
  can edit or run with another Enter. Nothing is ever executed automatically.
- **Any other key** restores your original request (`# list files sorted by size`).
- **Ctrl+C** or **Esc** while waiting cancels the request.

### Long mode: ask a question (`Ctrl+B`)

```text
❯ # difference between find -exec {} \; and {} +      ← press Ctrl+B

  -exec … \;  runs the command once per file
  -exec … +   passes as many files as possible to a single command
  …                                                   ← Markdown, rendered
❯                                                     ← fresh prompt
```

The question stays on screen and the answer is printed below it, rendered with
[glow](https://github.com/charmbracelet/glow), [bat](https://github.com/sharkdp/bat)
or [mdcat](https://github.com/swsnr/mdcat) if installed, otherwise with a
built-in renderer (headings, bold/italic, inline code, code blocks, lists,
quotes, links).

The leading `#` is optional. It is stripped before the request is sent, and
it keeps the line harmless if you press Enter by mistake (with
`setopt interactivecomments`).

## Requirements

- zsh ≥ 5.8
- `curl` and [`jq`](https://jqlang.github.io/jq/)
- Optional: `glow`, `bat` or `mdcat` for nicer Markdown rendering

## Installation

### zplug

```sh
zplug "giurlanda/zsh-terminal-assistant"
```

### Oh My Zsh

```sh
git clone https://github.com/giurlanda/zsh-terminal-assistant \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-terminal-assistant
```

Then add `zsh-terminal-assistant` to `plugins=(...)` in `~/.zshrc`.

### Manual

```sh
git clone https://github.com/giurlanda/zsh-terminal-assistant ~/.zsh/zsh-terminal-assistant
echo 'source ~/.zsh/zsh-terminal-assistant/zsh-terminal-assistant.plugin.zsh' >> ~/.zshrc
```

## Quick start

Set one API key, for example in `~/.zshrc`:

```sh
export ZTA_GEMINI_API_KEY="your-key-here"       # or
export ZTA_OPENAI_API_KEY="your-key-here"       # or
export ZTA_OPENROUTER_API_KEY="your-key-here"
```

Open a new shell, type `# show disk usage of this folder` and press `Ctrl+G`.

## Configuration

All settings are environment variables prefixed with `ZTA_`. The most common ones:

| Variable | Default | Purpose |
|---|---|---|
| `ZTA_PROVIDER` | auto-detected from the key that is set | `gemini`, `openai` or `openrouter` |
| `ZTA_MODEL` | provider default | Model name. Prefix it with `or:` to force OpenRouter |
| `ZTA_SHORT_HOTKEY` | `^g` (Ctrl+G) | Hotkey for short mode |
| `ZTA_LONG_HOTKEY` | `^b` (Ctrl+B) | Hotkey for long mode |
| `ZTA_RENDERER` | `auto` | `auto`, `glow`, `bat`, `mdcat`, `builtin` or `plain` |

See [docs/configuration.md](docs/configuration.md) for every option, provider
examples (including local OpenAI-compatible servers) and prompt customization.

> **Key bindings.** By default Ctrl+G replaces `send-break` and Ctrl+B replaces
> `backward-char` (emacs mode). Set `ZTA_SHORT_HOTKEY` / `ZTA_LONG_HOTKEY`
> *before* the plugin is loaded to use other keys, or set them to an empty
> string to disable a binding.

## Using it from scripts

The request function is public, so you can call it outside the line editor:

```sh
zta_request short "compress the logs folder"   # prints a single command
zta_request long  "what does set -euo pipefail do?" | glow -
```

## Security and privacy

- Generated commands are **never executed automatically**: you always see and
  approve them, and you can edit them before running. Review them carefully,
  especially destructive ones.
- The request text and a short description of your environment (OS type, CPU
  architecture, zsh version) are sent to the configured provider. Nothing else
  is sent: no files, no command history, no working directory.
- API keys are passed to `curl` through a configuration read from a file
  descriptor, so they never appear in the process list or in temporary files.

## Troubleshooting

- **Nothing happens / error message below the prompt:** run
  `zta_request short "list files"` in a shell to see the error directly.
- **Inspect the raw API traffic:** `export ZTA_DEBUG=true`. Request and response
  files are then kept in `$TMPDIR/zta.*`.
- **The hotkey does not work:** check `bindkey '^g'`. Another plugin loaded
  later may have rebound it.
- **Works with** zsh-autosuggestions and zsh-syntax-highlighting (tested in CI).

## Development

```sh
zsh tests/run.zsh                  # unit tests (fake curl, no network)
python3 tests/widgets_test.py      # widget tests in a pseudo-terminal
```

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
