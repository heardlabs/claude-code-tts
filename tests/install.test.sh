#!/usr/bin/env bash
# Tests for install.sh: it must merge into settings.json, never overwrite, back up first,
# be safe to run twice, replace the README's hand-written hook, and remove only its own
# hook and skill on --uninstall.
#   bash tests/install.test.sh
# Variables such as rc are read inside the quoted conditions that check() evals.
# shellcheck disable=SC2034,SC2016,SC2012
set -u
here="$(cd "$(dirname "$0")" && pwd)"
install="$here/../install.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $1"; }
bad() { fail=$((fail+1)); echo "  FAIL $1"; [ -n "${2:-}" ] && echo "       $2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

cfg="$work/claude"
s="$cfg/settings.json"
inst() { HOME="$work/home" CLAUDE_CONFIG_DIR="$cfg" bash "$install" "$@" >"$work/out" 2>&1; }
q() { jq -r "$1" "$s"; }
mkdir -p "$work/home"

echo "install.sh"

# 1. fresh install with no settings.json
inst; rc=$?
check "installs with no settings.json (exit 0)" '[ $rc -eq 0 ]' "$(cat "$work/out")"
check "creates settings.json with one Stop hook" '[ "$(q ".hooks.Stop | length")" = 1 ]' "$(cat "$s")"
check "Stop hook pipes last_assistant_message into speak.sh, async" \
  '[ "$(q ".hooks.Stop[0].hooks[0].async")" = true ] && q ".hooks.Stop[0].hooks[0].command" | grep -q "last_assistant_message.*skills/say/speak.sh"' "$(cat "$s")"
check "copies the skill, speak.sh executable" '[ -f "$cfg/skills/say/SKILL.md" ] && [ -x "$cfg/skills/say/speak.sh" ]'
check "installed files match the repo" \
  'cmp -s "$cfg/skills/say/speak.sh" "$here/../plugins/say/skills/say/speak.sh" && cmp -s "$cfg/skills/say/SKILL.md" "$here/../plugins/say/skills/say/SKILL.md"'
check "does not install the Codex skill unless asked" '[ ! -e "$work/home/.agents/skills/say" ]'

# The installed hook command runs: a fake say engine on PATH receives the reply text.
mkdir -p "$work/bin"
cat > "$work/bin/say" <<'F'
#!/bin/sh
cat >> "$SAY_LOG"
F
cp "$work/bin/say" "$work/bin/spd-say"; cp "$work/bin/say" "$work/bin/espeak-ng"
chmod +x "$work/bin/"*
cmd="$(q ".hooks.Stop[0].hooks[0].command")"
echo '{"last_assistant_message":"All tests pass."}' | SAY_LOG="$work/said" PATH="$work/bin:$PATH" TMPDIR="$work" sh -c "$cmd"
for _ in $(seq 1 50); do [ -s "$work/said" ] && break; sleep 0.1; done
check "the installed hook speaks the reply" 'grep -q "All tests pass" "$work/said" 2>/dev/null' "$(cat "$work/said" 2>/dev/null)"

# 2. merge into existing settings, replacing the README's hand-written hook
rm -rf "$cfg"; mkdir -p "$cfg"
cat > "$s" <<'J'
{
  "model": "opus",
  "permissions": {"allow": ["Bash(npm test)"]},
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "echo mine"}]}],
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "guard.sh"}]}]
  }
}
J
cp "$s" "$work/original.json"
jq '.hooks.Stop += [{"hooks":[{"type":"command","command":"jq -r '"'"'.last_assistant_message // empty'"'"' | bash ~/.claude/skills/say/speak.sh >/dev/null","async":true}]}]' "$s" > "$work/t" && cat "$work/t" > "$s"
cp "$s" "$work/with-readme-hook.json"
inst
check "keeps unrelated settings" '[ "$(q .model)" = opus ] && [ "$(q ".permissions.allow[0]")" = "Bash(npm test)" ]' "$(cat "$s")"
check "keeps the user's own Stop and PreToolUse hooks" \
  '[ "$(q ".hooks.Stop[0].hooks[0].command")" = "echo mine" ] && [ "$(q ".hooks.PreToolUse[0].hooks[0].command")" = guard.sh ]' "$(cat "$s")"
check "replaces the README's hand-written hook instead of adding a second voice" \
  '[ "$(q ".hooks.Stop | length")" = 2 ] && [ "$(jq "[.. | objects | select(has(\"command\")) | .command | select(test(\"speak.sh\"))] | length" "$s")" = 1 ]' "$(jq -c .hooks.Stop "$s")"
b="$(ls "$cfg"/settings.json.bak-* 2>/dev/null | head -n 1)"
check "writes a backup identical to the original first" '[ -n "$b" ] && cmp -s "$b" "$work/with-readme-hook.json"'

# 3. running twice does not duplicate
inst
check "second install does not add duplicates" '[ "$(q ".hooks.Stop | length")" = 2 ]' "$(jq -c .hooks.Stop "$s")"

# 4. --no-hook keeps the skill and drops the hook
inst --no-hook
check "--no-hook removes the Stop hook it added" '[ "$(q ".hooks.Stop | length")" = 1 ] && [ "$(q ".hooks.Stop[0].hooks[0].command")" = "echo mine" ]' "$(jq -c .hooks.Stop "$s")"
check "--no-hook keeps the skill" '[ -x "$cfg/skills/say/speak.sh" ]'

# 5. --with-codex also installs the skill for Codex
inst --with-codex
check "--with-codex installs the skill in ~/.agents/skills" '[ -x "$work/home/.agents/skills/say/speak.sh" ]'

# 6. uninstall restores the user's hooks and removes only our skill folders
inst --uninstall
check "uninstall restores the user's hooks exactly" \
  '[ "$(jq -S .hooks "$s")" = "$(jq -S .hooks "$work/original.json")" ]' "$(jq -c .hooks "$s")"
check "uninstall keeps unrelated settings" '[ "$(jq -S . "$s")" = "$(jq -S . "$work/original.json")" ]' "$(cat "$s")"
check "uninstall removes the skill folders it installed" '[ ! -e "$cfg/skills/say" ] && [ ! -e "$work/home/.agents/skills/say" ]'

# 7. install then uninstall on a fresh file gives back the same file
rm -rf "$cfg"; mkdir -p "$cfg"; echo '{"theme":"dark"}' > "$s"
inst; inst --uninstall
check "install then uninstall gives back the same file" '[ "$(jq -cS . "$s")" = "{\"theme\":\"dark\"}" ]' "$(cat "$s")"

# 8. a say skill the user made is never overwritten or removed
rm -rf "$cfg"; mkdir -p "$cfg/skills/say"; echo "my own skill" > "$cfg/skills/say/SKILL.md"
inst; rc=$?
check "leaves a say skill it did not install alone (and adds no hook without speak.sh)" \
  '[ "$(cat "$cfg/skills/say/SKILL.md")" = "my own skill" ] && [ $rc -ne 0 ] && [ ! -s "$s" -o "$(jq ".hooks.Stop // [] | length" "$s" 2>/dev/null)" = 0 ]' "$(cat "$work/out")"
inst --uninstall
check "uninstall does not remove a say skill it did not install" '[ -f "$cfg/skills/say/SKILL.md" ]'

# 9. invalid JSON: refuse and change nothing
rm -rf "$cfg"; mkdir -p "$cfg"; printf '{"a": 1,' > "$s"; cp "$s" "$work/bad.json"
inst; rc=$?
check "refuses invalid settings.json and leaves it unchanged" '[ $rc -eq 65 ] && cmp -s "$s" "$work/bad.json"' "$(cat "$work/out")"

# 10. no jq: refuse with a hint
rm -rf "$cfg"; mkdir -p "$work/nojq"
for t in bash sh cat mkdir dirname date cp mv chmod rm sed mktemp; do p="$(command -v "$t")" && ln -sf "$p" "$work/nojq/$t"; done
HOME="$work/home" CLAUDE_CONFIG_DIR="$cfg" PATH="$work/nojq" bash "$install" >"$work/out" 2>&1; rc=$?
check "without jq: exit 69 with an install hint" '[ $rc -eq 69 ] && grep -q "brew install jq" "$work/out"' "$(cat "$work/out")"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
