# Configuration

zsh-terminal-assistant is configured with environment variables prefixed with
`ZTA_`. Set them in `~/.zshrc`. Most settings are read on every request, so an
`export` in the current shell takes effect immediately. The hotkeys are the
exception: they are bound when the plugin loads.

## Installation

Using [zplug](https://github.com/zplug/zplug):

```sh
zplug "giurlanda/zsh-terminal-assistant"
```

## Providers

### Gemini

```sh
export ZTA_GEMINI_API_KEY="your-key-here"
```

### OpenAI

```sh
export ZTA_OPENAI_API_KEY="your-key-here"
```

By default the plugin calls the [Responses API](https://platform.openai.com/docs/api-reference/responses)
with priority processing (`ZTA_OPENAI_FAST=true`), which lowers latency at a
higher price. Set `ZTA_OPENAI_FAST=false` to use the standard tier.

### OpenRouter

```sh
export ZTA_OPENROUTER_API_KEY="your-key-here"
# Optional — defaults to openai/gpt-oss-120b:nitro
export ZTA_MODEL="qwen/qwen3.5-35b-a3b:nitro"
```

Or use the `or:` model prefix to switch provider with a single variable:

```sh
export ZTA_MODEL=or:qwen/qwen3.5-35b-a3b:nitro
```

The prefix forces `ZTA_PROVIDER=openrouter` and is removed before the request
is sent. This is useful when several keys are set and you want to switch
provider without touching `ZTA_PROVIDER`.

### OpenAI-compatible APIs (llama.cpp, LM Studio, Ollama, …)

```sh
export ZTA_PROVIDER=openai
export ZTA_OPENAI_ENDPOINT="http://localhost:11434/v1/chat/completions"
export ZTA_MODEL="LiquidAI/LFM2.5-1.2B-Thinking"
# Only if your server requires one:
export ZTA_OPENAI_API_KEY="your-key"
```

When the endpoint ends with `/chat/completions` the plugin uses the Chat
Completions format. With any endpoint other than `https://api.openai.com/...`
the API key is optional and priority processing is never requested.
`<think>…</think>` blocks emitted by reasoning models are removed from the answer.

### Provider selection

1. A model with the `or:` prefix always selects OpenRouter.
2. Otherwise `ZTA_PROVIDER` is used, if set.
3. Otherwise the first key found is used, in this order: Gemini, OpenAI, OpenRouter.

## All environment variables

| Variable | Default | Purpose |
|---|---|---|
| `ZTA_PROVIDER` | Auto-detected from which key is set | `gemini`, `openai` or `openrouter` |
| `ZTA_MODEL` | `gemini-3-flash-preview` / `gpt-4.1-mini` / `openai/gpt-oss-120b:nitro` | Model identifier (prefix with `or:` to force OpenRouter) |
| `ZTA_GEMINI_API_KEY` | — | Gemini API key |
| `ZTA_OPENAI_API_KEY` | — | OpenAI API key (optional for custom endpoints) |
| `ZTA_OPENAI_ENDPOINT` | `https://api.openai.com/v1/responses` | Custom endpoint (use `/v1/chat/completions` for OpenAI-compatible servers) |
| `ZTA_OPENAI_FAST` | `true` | OpenAI priority processing (lower latency, higher cost). Official API only |
| `ZTA_OPENROUTER_API_KEY` | — | OpenRouter API key |
| `ZTA_SHORT_HOTKEY` | `^g` (Ctrl+G) | Short mode keybinding. Set before loading. Empty disables it |
| `ZTA_LONG_HOTKEY` | `^b` (Ctrl+B) | Long mode keybinding. Set before loading. Empty disables it |
| `ZTA_RENDERER` | `auto` | Markdown renderer: `auto`, `glow`, `bat`, `mdcat`, `builtin`, `plain` |
| `ZTA_SHORT_PROMPT` | built-in | Replaces the short mode system prompt |
| `ZTA_LONG_PROMPT` | built-in | Replaces the long mode system prompt |
| `ZTA_TIMEOUT` | `60` | Request timeout in seconds |
| `ZTA_HISTORY` | `false` | Add the natural-language requests to the shell history |
| `ZTA_DEBUG` | `false` | Keep request/response files in `$TMPDIR/zta.*` for debugging |

Boolean variables accept `true`/`false`, `1`/`0`, `yes`/`no` and `on`/`off`.

## Hotkeys

The hotkeys are bound in the `emacs`, `viins` and `vicmd` keymaps using
`bindkey` syntax:

```sh
export ZTA_SHORT_HOTKEY='^[a'   # Alt+A
export ZTA_LONG_HOTKEY='^x^a'   # Ctrl+X Ctrl+A
zplug "giurlanda/zsh-terminal-assistant"
```

You can also bind the widgets yourself and set the variables to an empty string:

```sh
export ZTA_SHORT_HOTKEY= ZTA_LONG_HOTKEY=
bindkey '^[g' zta-short-widget
bindkey '^[b' zta-long-widget
```

## Markdown rendering

With `ZTA_RENDERER=auto`, long mode uses the first renderer available in this
order: `glow`, `bat` (`batcat` on Debian/Ubuntu), `mdcat`, and finally the
built-in renderer, which needs only `awk`. If you force a renderer that is not
installed, the plugin falls back to the built-in one. `plain` prints the raw
Markdown.

## Prompts

`ZTA_SHORT_PROMPT` and `ZTA_LONG_PROMPT` replace the default system prompts. A
line describing your environment (OS type, CPU architecture, zsh version) is
always appended, so the model can choose the right command flavour, for example
BSD vs GNU flags. In short mode, keep asking for a single command line: the
plugin keeps only the first line of the answer, or the first code block if
there is one.

## Usage

1. Type a natural language description in your terminal, e.g. `# list files`
2. Press Ctrl+G (or your configured hotkey)
3. Accept (Enter) or discard (any other key) the generated command

For explanations, press Ctrl+B instead: the answer is rendered as Markdown
below your question.
