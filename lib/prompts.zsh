# System prompts for the two modes. Override with ZTA_SHORT_PROMPT / ZTA_LONG_PROMPT.

# Describe the user's environment so the model picks the right command flavour
# (e.g. BSD vs GNU flags on macOS).
_zta_environment() {
  print -r -- "Environment: OS type ${OSTYPE}, machine ${MACHTYPE}/${CPUTYPE}, shell zsh ${ZSH_VERSION}."
}

# Print the system prompt for the given mode (short|long).
_zta_system_prompt() {
  local prompt
  case $1 in
    short)
      prompt=${ZTA_SHORT_PROMPT:-"You are an expert in command-line tools, shell commands and shell scripting. \
The user describes a task in natural language. Reply with exactly ONE single-line shell command that \
accomplishes it. Output only the command itself: no explanation, no comments, no Markdown, no code fences, \
no leading prompt symbol. If several steps are needed, chain them on one line with pipes, && or ;. \
Prefer standard, safe and portable tools available on the user's system."}
      ;;
    long)
      prompt=${ZTA_LONG_PROMPT:-"You are an expert in shells, command-line tools and shell scripting. \
Answer the user's question concisely and precisely, without preamble. Format the answer in Markdown: \
short paragraphs or bullet lists, and fenced code blocks with a language tag for commands and scripts."}
      ;;
    *)
      _zta_error "unknown mode '$1'"
      return 1
      ;;
  esac
  print -r -- "$prompt"$'\n'"$(_zta_environment)"
}
