# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project follows [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-09-24

### Added

- Short mode (Ctrl+G): turns a natural-language request into a single shell
  command shown in cyan, to accept with Enter or discard with any other key.
- Long mode (Ctrl+B): concise Markdown answers rendered with glow, bat, mdcat
  or a built-in awk renderer.
- Providers: Gemini, OpenAI (Responses and Chat Completions APIs, priority
  processing), OpenRouter, and OpenAI-compatible local servers.
- `or:` model prefix to force OpenRouter.
- Animated spinner while waiting, with cancellation via Ctrl+C or Esc.
- Configuration through `ZTA_*` environment variables, including custom
  prompts, timeout, history logging and debug mode.
- Public `zta_request` function for use outside the line editor.
- Unit tests with a fake curl and pseudo-terminal widget tests.
