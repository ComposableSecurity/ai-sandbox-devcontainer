#!/usr/bin/env bash
# Populate .mount-cache/ with either symlinks to host files (when the user
# consents) or empty placeholders (otherwise). devcontainer.json mounts
# bind from this cache, so the mounts are always wired, but the content
# the container sees is controlled by the user's recorded preferences.
#
# Prefs are cached in .mount-prefs; delete an entry (or the whole file) to
# be re-asked on the next devcontainer build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$SCRIPT_DIR/.mount-cache"
PREFS_FILE="$SCRIPT_DIR/.mount-prefs"

mkdir -p "$CACHE_DIR"
touch "$PREFS_FILE"

get_pref() {
  grep "^$1=" "$PREFS_FILE" 2>/dev/null | tail -n1 | cut -d= -f2-
}

set_pref() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  grep -v "^${key}=" "$PREFS_FILE" > "$tmp" 2>/dev/null || true
  echo "${key}=${value}" >> "$tmp"
  mv "$tmp" "$PREFS_FILE"
}

ask_consent() {
  local desc="$1"
  if [ ! -e /dev/tty ]; then
    echo "[setup-mounts] no TTY available; defaulting to 'no' for: $desc" >&2
    echo "[setup-mounts] edit .mount-prefs to change, or run this script in a terminal." >&2
    echo "no"
    return
  fi
  local ans
  while :; do
    printf 'Mount %s (read-only) into the devcontainer? [y/N] ' "$desc" > /dev/tty
    if ! IFS= read -r ans < /dev/tty; then
      echo "no"
      return
    fi
    case "${ans:-n}" in
      y|Y|yes|YES) echo "yes"; return ;;
      n|N|no|NO|"") echo "no"; return ;;
    esac
  done
}

setup_one() {
  local key="$1" host_path="$2" cache_name="$3" kind="$4" desc="$5"
  local cache_path="$CACHE_DIR/$cache_name"

  rm -rf "$cache_path"

  if [ ! -e "$host_path" ]; then
    if [ "$kind" = "dir" ]; then mkdir -p "$cache_path"; else : > "$cache_path"; fi
    return
  fi

  local pref
  pref="$(get_pref "$key")"
  if [ -z "$pref" ]; then
    pref="$(ask_consent "$desc")"
    set_pref "$key" "$pref"
  fi

  if [ "$pref" = "yes" ]; then
    ln -s "$host_path" "$cache_path"
  else
    if [ "$kind" = "dir" ]; then mkdir -p "$cache_path"; else : > "$cache_path"; fi
  fi
}

setup_one "gitconfig"       "$HOME/.gitconfig"        "gitconfig"       "file" "your ~/.gitconfig"
setup_one "claude_commands" "$HOME/.claude/commands"  "claude-commands" "dir"  "your ~/.claude/commands"
setup_one "codex_commands"  "$HOME/.codex/commands"   "codex-commands"  "dir"  "your ~/.codex/commands"
