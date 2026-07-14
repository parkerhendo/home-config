typeset -U path PATH

path_prepend() {
  local dir
  local dirs=()

  for dir in "$@"; do
    [ -d "$dir" ] && dirs+=("$dir")
  done

  path=("${dirs[@]}" "${path[@]}")
}

path_append() {
  local dir

  for dir in "$@"; do
    [ -d "$dir" ] && path+=("$dir")
  done
}

path_clean() {
  local dir
  local dirs=()

  for dir in "${path[@]}"; do
    [ -d "$dir" ] && dirs+=("$dir")
  done

  path=("${dirs[@]}")
}

export NINJA_DIR="$HOME/ninja/ninja"
export CKIT_DIR="$HOME/ckit"

path_prepend \
  "$HOME/.local/share/mise/shims" \
  "$HOME/.local/bin" \
  "$HOME/.npm-global/bin" \
  "$HOME/.bun/bin" \
  "$HOME/.yarn/bin" \
  "$HOME/.config/yarn/global/node_modules/.bin" \
  "$HOME/.cargo/bin" \
  "/Applications/CMake.app/Contents/bin" \
  "/opt/homebrew/bin" \
  "/opt/homebrew/sbin"

path_append \
  "$NINJA_DIR" \
  "$CKIT_DIR/bin"

path_clean

export PATH
unset -f path_prepend path_append path_clean
