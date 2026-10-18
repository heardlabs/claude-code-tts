#!/usr/bin/env bash
# Unit tests for skills/say/speak.sh, using fake voice engines (no audio needed).
#   bash tests/speak.test.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
speak="$here/../skills/say/speak.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "  ok   $1"; }
bad()  { fail=$((fail+1)); echo "  FAIL $1"; [ -n "${2:-}" ] && echo "       $2"; }

# A fake engine records its arguments and the text it got on stdin, one line per call.
fake() { # fake <name> <dir> [delay]
  mkdir -p "$2"
  cat > "$2/$1" <<F
#!/bin/sh
sleep ${3:-0}
printf '%s|%s|%s\n' "\$(date +%s%N)" "\$*" "\$(cat)" >> "$work/log.$1"
F
  chmod +x "$2/$1"
}
# Run speak.sh with only the given bin dir (plus coreutils) on PATH.
run() { local bin="$1"; shift; env -i HOME="$HOME" TMPDIR="$work/tmp" PATH="$bin:/usr/bin:/bin" ${SAY_ENV:-} bash "$speak" "$@"; }
waitlog() { for _ in $(seq 1 50); do [ -f "$1" ] && [ "$(wc -l < "$1")" -ge "$2" ] && return 0; sleep 0.1; done; return 1; }
mkdir -p "$work/tmp"

echo "speak.sh"

# 1. argument text reaches the engine on stdin
fake espeak-ng "$work/b1"; rm -f "$work/log.espeak-ng"
out="$(run "$work/b1" "Tests pass. Your call.")"
waitlog "$work/log.espeak-ng" 1 && grep -q '|--stdin|Tests pass. Your call.$' "$work/log.espeak-ng" \
  && ok "argument text goes to the engine on stdin" || bad "argument text goes to the engine on stdin" "$(cat "$work/log.espeak-ng" 2>/dev/null)"
[ "$out" = "speaking: Tests pass. Your call." ] && ok "prints what it speaks" || bad "prints what it speaks" "$out"

# 2. stdin text
rm -f "$work/log.espeak-ng"
echo "deploy done" | run "$work/b1" >/dev/null
waitlog "$work/log.espeak-ng" 1 && grep -q '|deploy done$' "$work/log.espeak-ng" && ok "reads text from stdin" || bad "reads text from stdin"

# 3. text starting with a dash is not an option
rm -f "$work/log.espeak-ng"
run "$work/b1" "-v is not a flag" >/dev/null
waitlog "$work/log.espeak-ng" 1 && grep -q '|--stdin|-v is not a flag$' "$work/log.espeak-ng" && ok "leading dash is spoken, not parsed" || bad "leading dash is spoken, not parsed" "$(cat "$work/log.espeak-ng")"

# 4. markdown stripped, newlines flattened
rm -f "$work/log.espeak-ng"
run "$work/b1" $'**Done.** Run `npm test`\n# next' >/dev/null
waitlog "$work/log.espeak-ng" 1 && grep -q '|Done. Run npm test  next$' "$work/log.espeak-ng" && ok "strips markdown and newlines" || bad "strips markdown and newlines" "$(cat "$work/log.espeak-ng")"

# 5. long text capped at 600 characters
rm -f "$work/log.espeak-ng"
run "$work/b1" "$(printf 'a%.0s' $(seq 1 900))" >/dev/null
waitlog "$work/log.espeak-ng" 1; n="$(cut -d'|' -f3 "$work/log.espeak-ng" | tr -d '\n' | wc -c)"
[ "$n" -eq 600 ] && ok "caps text at 600 characters" || bad "caps text at 600 characters" "got $n"

# 6. empty text
run "$work/b1" "   " >/dev/null 2>&1; [ $? -eq 1 ] && ok "empty text exits 1" || bad "empty text exits 1"

# 7. voice and rate options
rm -f "$work/log.espeak-ng"
SAY_ENV="SAY_VOICE=en-us SAY_RATE=210" run "$work/b1" "hi" >/dev/null
waitlog "$work/log.espeak-ng" 1 && grep -q '|--stdin -v en-us -s 210|hi$' "$work/log.espeak-ng" && ok "SAY_VOICE and SAY_RATE reach espeak" || bad "SAY_VOICE and SAY_RATE reach espeak" "$(cat "$work/log.espeak-ng")"

# 8. engine preference: macOS say wins, with -f -
fake say "$work/b2"; fake espeak-ng "$work/b2"; rm -f "$work/log.say" "$work/log.espeak-ng"
SAY_ENV="SAY_VOICE=Samantha SAY_RATE=200" run "$work/b2" "mac" >/dev/null
waitlog "$work/log.say" 1 && grep -q '|-f - -v Samantha -r 200|mac$' "$work/log.say" && [ ! -f "$work/log.espeak-ng" ] \
  && ok "prefers macOS say with -f - and options" || bad "prefers macOS say with -f - and options" "$(cat "$work/log.say" 2>/dev/null)"

# 9. spd-say used with -w -e
fake spd-say "$work/b3"; rm -f "$work/log.spd-say"
run "$work/b3" "linux" >/dev/null
waitlog "$work/log.spd-say" 1 && grep -q '|-w -e|linux$' "$work/log.spd-say" && ok "uses spd-say with -w -e" || bad "uses spd-say with -w -e" "$(cat "$work/log.spd-say" 2>/dev/null)"

# 10. PowerShell on WSL / Windows
fake powershell.exe "$work/b4"; rm -f "$work/log.powershell.exe"
run "$work/b4" "windows" >/dev/null
waitlog "$work/log.powershell.exe" 1 && grep -q 'System.Speech.*|windows$' "$work/log.powershell.exe" && ok "uses PowerShell System.Speech" || bad "uses PowerShell System.Speech" "$(cat "$work/log.powershell.exe" 2>/dev/null)"

# 11. no engine
mkdir -p "$work/empty"
err="$(run "$work/empty" "hello" 2>&1 >/dev/null)"; code=$?
[ $code -eq 2 ] && echo "$err" | grep -q "no text-to-speech engine" && ok "no engine exits 2 with install hint" || bad "no engine exits 2 with install hint" "code $code: $err"

# 12. returns at once, speech continues in the background
fake espeak-ng "$work/b5" 1.5; rm -f "$work/log.espeak-ng"
t0=$(date +%s%N); run "$work/b5" "slow" >/dev/null; dt=$(( ($(date +%s%N)-t0)/1000000 ))
[ $dt -lt 1000 ] && ok "returns at once (${dt} ms)" || bad "returns at once" "${dt} ms"
waitlog "$work/log.espeak-ng" 1 && ok "speech still finishes after it returns" || bad "speech still finishes after it returns"

# 13. parallel calls queue: no overlap, all spoken
cat > "$work/b6-espeak" <<F
#!/bin/sh
start=\$(date +%s%N); sleep 0.6; t="\$(cat)"
printf '%s %s %s\n' "\$start" "\$(date +%s%N)" "\$t" >> "$work/log.queue"
F
mkdir -p "$work/b6"; mv "$work/b6-espeak" "$work/b6/espeak-ng"; chmod +x "$work/b6/espeak-ng"; rm -f "$work/log.queue"
for i in 1 2 3 4; do run "$work/b6" "session $i" >/dev/null & done; wait
waitlog "$work/log.queue" 4 || true
lines=$(wc -l < "$work/log.queue" 2>/dev/null || echo 0)
overlap=$(sort -n "$work/log.queue" | awk 'NR>1 && $1 < prev_end {o=1} {prev_end=$2} END {print o+0}')
[ "$lines" -eq 4 ] && ok "four parallel calls all spoken" || bad "four parallel calls all spoken" "got $lines"
[ "$overlap" -eq 0 ] && ok "parallel calls never overlap" || bad "parallel calls never overlap" "$(cat "$work/log.queue")"
[ ! -d "$work/tmp/claude-say.lock" ] && ok "lock released afterwards" || bad "lock released afterwards"

# 14. stale lock (older than 2 minutes) is taken over
mkdir -p "$work/tmp/claude-say.lock"; touch -d '5 minutes ago' "$work/tmp/claude-say.lock"; rm -f "$work/log.espeak-ng"
run "$work/b1" "after stale lock" >/dev/null
waitlog "$work/log.espeak-ng" 1 && ok "takes over a stale lock" || bad "takes over a stale lock"

echo
echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
