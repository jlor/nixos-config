# ~/.config/spaceship.zsh — Spaceship prompt settings
# Docs: https://spaceship-prompt.sh/config/intro/
# Spaceship shows language/tool sections (node, java, nix_shell, kubectl, terraform, ...)
# automatically when they apply to the current directory.

# 👍 when the last command succeeded, 👎 when it failed
SPACESHIP_CHAR_SYMBOL_SUCCESS="👍 "
SPACESHIP_CHAR_SYMBOL_FAILURE="👎 "
SPACESHIP_CHAR_SYMBOL_SECONDARY="… "

# Blank line between prompts, prompt on its own line
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_PROMPT_SEPARATE_LINE=true

# Show how long slow commands took
SPACESHIP_EXEC_TIME_ELAPSED=2

# Catppuccin-ish accents
SPACESHIP_DIR_COLOR="magenta"
SPACESHIP_GIT_BRANCH_COLOR="yellow"
SPACESHIP_NIX_SHELL_COLOR="blue"
