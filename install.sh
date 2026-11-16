#!/usr/bin/env bash
# Install the /say skill and a Stop hook that reads Claude Code's replies aloud.
#
#   bash install.sh                 install, or update an earlier install
#   bash install.sh --no-hook       install only the /say skill, no Stop hook
#   bash install.sh --with-codex    also install the skill for Codex ($say), in ~/.agents/skills
#   bash install.sh --uninstall     remove only what this script added
#
# It MERGES into ~/.claude/settings.json with jq and never overwrites your other settings
# or hooks. A timestamped backup of settings.json is written before every change.
# Hook reference: https://code.claude.com/docs/en/hooks
# jq programs are single-quoted on purpose.
# shellcheck disable=SC2016
set -euo pipefail

raw="https://raw.githubusercontent.com/heardlabs/claude-code-tts/main/plugins/say/skills/say"
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$config_dir/settings.json"
dest="$config_dir/skills/say"
codex_dest="$HOME/.agents/skills/say"
marker=".installed-by-claude-code-tts"

mode="install"; hook=1; codex=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) mode="uninstall" ;;
    --no-hook) hook=0 ;;
    --with-codex) codex=1 ;;
    -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null || true; exit 0 ;;
    *) echo "install.sh: unknown option $arg" >&2; exit 64 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "install.sh: jq is needed to edit settings.json safely (and the Stop hook uses it)." >&2
  echo "  macOS: brew install jq    Debian/Ubuntu: sudo apt install jq    Windows: winget install jqlang.jq" >&2
  exit 69
fi

# jq: is this handler one of ours? It pipes last_assistant_message into a say/speak.sh.
# The README's hand-written hook matches too, so installing replaces it instead of adding a second voice.
ours_def='def ours: ((.command? // "") | tostring | (test("last_assistant_message") and test("say/speak\\.sh")));'

# jq: remove our handlers from Stop. Matcher groups and the Stop list are deleted only when
# removing our handler left them empty.
strip="$ours_def"'
  def group_has_ours: ((.hooks? // []) | type == "array") and any((.hooks? // [])[]; ours);
  if (.hooks | type) == "object" and ((.hooks.Stop // []) | type) == "array" then
    .hooks.Stop = ((.hooks.Stop // []) | map(if group_has_ours then (.hooks |= map(select(ours | not))) | select(.hooks | length > 0) else . end))
    | if .hooks.Stop == [] then del(.hooks.Stop) else . end
    | if .hooks == {} then del(.hooks) else . end
  else . end'

add='
  .hooks = (.hooks // {})
  | .hooks.Stop = ((.hooks.Stop // []) + [{"hooks": [{"type": "command", "command": $cmd, "async": true}]}])'

has_ours() { [ -s "$settings" ] && jq -e "$ours_def"' [.. | objects | select(has("command")) | select(ours)] | length > 0' "$settings" >/dev/null 2>&1; }

check_settings() {
  [ -s "$settings" ] || return 0   # missing or empty: treated as {}
  if ! jq -e -s 'length == 1 and (.[0] | type) == "object"' "$settings" >/dev/null 2>&1; then
    echo "install.sh: $settings is not valid JSON. Fix it first; nothing was changed." >&2; exit 65
  fi
  if ! jq -e '(.hooks == null or (.hooks | type) == "object")
              and ((.hooks.Stop // []) | type) == "array"' "$settings" >/dev/null 2>&1; then
    echo "install.sh: the \"hooks\" section of $settings has an unexpected shape. Nothing was changed." >&2; exit 65
  fi
}

backup() {
  [ -f "$settings" ] || return 0
  local b; b="$settings.bak-$(date +%Y%m%d-%H%M%S)"
  [ -e "$b" ] && b="$b-$$"
  cp -p "$settings" "$b"
  echo "Backed up $settings to $b"
}

# write <jq args...>: run jq over settings.json into a temp file, check it, then copy it back
# in place (cat keeps a symlinked settings.json and its permissions intact).
write() {
  local tmp ok=1; tmp="$(mktemp "$config_dir/.settings.json.XXXXXX")"
  if [ -s "$settings" ]; then jq "$@" "$settings" > "$tmp" || ok=0; else echo '{}' | jq "$@" > "$tmp" || ok=0; fi
  if [ "$ok" = 0 ] || ! jq -e -s 'length == 1 and (.[0] | type) == "object"' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"; echo "install.sh: jq failed; $settings was not changed." >&2; exit 70
  fi
  cat "$tmp" > "$settings"
  rm -f "$tmp"
}

# remove_skill <dir>: delete a skill folder only if this script put it there.
remove_skill() { if [ -f "$1/$marker" ]; then rm -rf "$1"; echo "Removed $1"; fi; }

# put_skill <dir>: copy SKILL.md and speak.sh into <dir>. A say skill this script did not
# install is left alone.
put_skill() {
  local d="$1" src
  if [ -e "$d" ] && [ ! -f "$d/$marker" ]; then
    echo "install.sh: $d already exists and was not installed by this script; left it alone." >&2
    return 1
  fi
  mkdir -p "$d"
  src="${BASH_SOURCE[0]:-}"
  if [ -n "$src" ] && [ -f "$src" ] && [ -f "$(dirname "$src")/plugins/say/skills/say/speak.sh" ]; then
    cp "$(dirname "$src")/plugins/say/skills/say/SKILL.md" "$d/SKILL.md.new"
    cp "$(dirname "$src")/plugins/say/skills/say/speak.sh" "$d/speak.sh.new"
  else
    curl -fsSL "$raw/SKILL.md" -o "$d/SKILL.md.new"
    curl -fsSL "$raw/speak.sh" -o "$d/speak.sh.new"
  fi
  mv "$d/SKILL.md.new" "$d/SKILL.md"
  mv "$d/speak.sh.new" "$d/speak.sh"
  chmod +x "$d/speak.sh"
  : > "$d/$marker"
}

if [ "$mode" = "uninstall" ]; then
  check_settings
  if has_ours; then
    backup
    write "$strip"
    echo "Removed the read-aloud Stop hook from $settings. Your other hooks are untouched."
  else
    echo "No read-aloud Stop hook found in $settings."
  fi
  remove_skill "$dest"
  remove_skill "$codex_dest"
  exit 0
fi

mkdir -p "$config_dir"
check_settings
case "$dest" in *"'"*|*'"'*) echo "install.sh: the path $dest contains a quote character; set CLAUDE_CONFIG_DIR to a simpler path." >&2; exit 64 ;; esac

# 1. The /say skill, with speak.sh, where Claude Code finds personal skills.
skill_ok=1
put_skill "$dest" || skill_ok=0
if [ "$codex" = 1 ]; then put_skill "$codex_dest" || true; fi
speak="$dest/speak.sh"
if [ "$skill_ok" = 0 ] && [ ! -f "$speak" ]; then
  echo "install.sh: no speak.sh at $speak, so no hook was added." >&2; exit 1
fi

# 2. The Stop hook: drop an earlier copy of ours (or the README's hand-written one), then append a
#    fresh one. Your other Stop hooks are left alone.
if [ "$hook" = 1 ]; then
  cmd="jq -r '.last_assistant_message // empty' | bash '$speak' >/dev/null"
  backup
  write --arg cmd "$cmd" "$strip | $add"
  echo "Added a Stop hook to $settings that reads each Claude Code reply aloud."
  if jq -e '.disableAllHooks == true' "$settings" >/dev/null 2>&1; then
    echo "Note: \"disableAllHooks\" is true in $settings, so no hooks run until you change it."
  fi
elif has_ours; then
  backup
  write "$strip"
  echo "Removed the read-aloud Stop hook (--no-hook)."
fi

cat <<EOF

Installed the /say skill in $dest.
Try the voice now:    bash '$speak' 'Claude Code can talk now'
Uninstall:            curl -fsSL https://raw.githubusercontent.com/heardlabs/claude-code-tts/main/install.sh | bash -s -- --uninstall

Claude Code picks up settings changes on its own. Type /hooks in Claude Code to see the Stop hook,
then ask Claude something short. Type /say for a spoken summary.
EOF
