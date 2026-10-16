---
name: say
description: Speak out loud on this computer with its built-in text-to-speech voice. Use when the user types /say or $say, or asks you to say something aloud, read something out, or tell them by voice what you did. With text, speaks that text. Without text, speaks a one or two sentence summary of where the work stands. Do not use for writing files or for voice input.
argument-hint: "[text to speak]"
allowed-tools: Bash(bash *speak.sh*)
---

Speak to the user through their computer's speakers.

1. Decide what to say.
   - If the user gave text ($ARGUMENTS), say exactly that.
   - Otherwise write a spoken update of at most 40 words: name the project and what you were doing in a few words, give the outcome (done, failed, or blocked), and end with the next step and who owns it ("your call on the migration", "I'll start the tests next").
   - Write for the ear: no code, file paths, URLs, markdown or emoji. Say numbers and symbols as words where needed ("two tests failed", not "2/14 ✗").
2. Run the `speak.sh` script that sits next to this SKILL.md, with the text as one quoted argument. In Claude Code the path is `${CLAUDE_SKILL_DIR}/speak.sh`:

   ```bash
   bash "<this skill's folder>/speak.sh" "Tests pass. I fixed the date parser and I have one question about the migration."
   ```

   It returns immediately and the voice plays in the background, so carry on working. If other sessions are speaking, it waits its turn instead of talking over them.
3. Also write the same sentence in your reply, so it is on screen too.

If the script says no voice engine was found, tell the user what to install: on Linux `espeak-ng` or `speech-dispatcher`. macOS and Windows (including WSL) need nothing. Voice and speed can be set with the `SAY_VOICE` and `SAY_RATE` environment variables.
