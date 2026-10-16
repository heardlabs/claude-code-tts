#!/usr/bin/env bash
# Speak text with the computer's built-in voice, in the background, and return at once.
#   speak.sh "text"        or        echo "text" | speak.sh
# macOS: say. Linux: spd-say, espeak-ng or espeak. Windows / WSL: PowerShell System.Speech.
# Optional: SAY_VOICE (voice name), SAY_RATE (words per minute).
set -u

if [ $# -gt 0 ]; then text="$*"; else text="$(cat)"; fi
# Strip markdown marks and newlines, cap the length so a long reply is not read for minutes.
text="$(printf '%s' "$text" | tr -d '`*_#>' | tr '\n\r\t' '   ' | cut -c1-600)"
[ -n "${text// /}" ] || { echo "speak.sh: nothing to say" >&2; exit 1; }

voice="${SAY_VOICE:-}"
rate="${SAY_RATE:-}"

# Text always goes in on stdin, so text starting with "-" is never read as an option.
if command -v say >/dev/null 2>&1; then
  args=(-f -)
  [ -n "$voice" ] && args+=(-v "$voice")
  [ -n "$rate" ] && args+=(-r "$rate")
  printf '%s' "$text" | nohup say "${args[@]}" >/dev/null 2>&1 &
elif command -v spd-say >/dev/null 2>&1; then
  args=(-e)
  [ -n "$voice" ] && args+=(-y "$voice")
  printf '%s' "$text" | nohup spd-say "${args[@]}" >/dev/null 2>&1 &
elif command -v espeak-ng >/dev/null 2>&1 || command -v espeak >/dev/null 2>&1; then
  bin="$(command -v espeak-ng || command -v espeak)"
  args=(--stdin)
  [ -n "$voice" ] && args+=(-v "$voice")
  [ -n "$rate" ] && args+=(-s "$rate")
  printf '%s' "$text" | nohup "$bin" "${args[@]}" >/dev/null 2>&1 &
elif command -v powershell.exe >/dev/null 2>&1; then
  printf '%s' "$text" | nohup powershell.exe -NoProfile -Command \
    'Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak([Console]::In.ReadToEnd())' \
    >/dev/null 2>&1 &
else
  echo "speak.sh: no text-to-speech engine found. On Linux install espeak-ng or speech-dispatcher." >&2
  exit 2
fi

echo "speaking: $text"
