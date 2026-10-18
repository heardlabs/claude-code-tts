---
name: say
description: Speak a short spoken briefing out loud on this computer with its built-in text-to-speech voice. Use when the user types /say or $say, or asks you to say something aloud, read something out, or tell them by voice where the work stands. Without text, speaks a briefing (context, outcome, next action and its owner). With text, speaks that text. Do not use for writing files or for voice input.
argument-hint: "[short | long | text to speak]"
allowed-tools: Bash(bash *speak.sh*)
---

Brief the user out loud, the way a teammate would in a doorway: what this is, how it went, and who moves next.

## 1. Decide what to say

- `$ARGUMENTS` is `short` or `long`: write a briefing at that length (below).
- `$ARGUMENTS` is any other text: say exactly that text and skip the format.
- No arguments: write a normal-length briefing.

### The briefing format

Three parts, in this order:

1. **Context.** Which project or task, in a few words, so the user knows which of their sessions is talking. "In the billing service," "On the flaky login test."
2. **Outcome.** Done, failed, blocked, or still going, plus the one fact that matters. "All forty tests pass." "The deploy failed on a missing env var."
3. **Next action and owner.** End on what happens next and who does it. If the user must act, make it a direct ask: "your call on the migration," "I need the API key." If you carry on, say so: "I'll start the docs next." Never end without an owner.

Lengths:

| Length | Words | Use |
|---|---|---|
| `short` | up to 15 | Context and next action only. "Billing refactor done, migration is your call." |
| normal | up to 35 | All three parts, one or two sentences. |
| `long` | up to 70 | All three parts, plus the one risk or decision the user should know about. |

Write for the ear:

- Plain spoken sentences. No code, file paths, URLs, markdown, emoji or lists.
- Numbers and symbols as words where needed: "two tests failed", not "2/14 ✗".
- Lead with the user's concern, not your process. Skip "I have completed the task of...".

Good: "In the billing service, the refactor is done and all tests pass. The schema migration is next, and it's your call whether to run it today."
Bad: "I made changes to src/billing/invoice.ts and ran npm test." (no outcome, no next step, reads a path aloud)

## 2. Speak it

Run the `speak.sh` script that sits next to this SKILL.md, with the text as one quoted argument. In Claude Code the path is `${CLAUDE_SKILL_DIR}/speak.sh`:

```bash
bash "<this skill's folder>/speak.sh" "In the billing service, the refactor is done and all tests pass. The migration is your call."
```

It returns immediately and the voice plays in the background, so carry on working. If other sessions are speaking, it waits its turn instead of talking over them.

## 3. Show it

Write the same sentence in your reply, so it is on screen too.

If the script says no voice engine was found, tell the user what to install: on Linux `espeak-ng` or `speech-dispatcher`. macOS and Windows (including WSL) need nothing. Voice and speed can be set with the `SAY_VOICE` and `SAY_RATE` environment variables.
