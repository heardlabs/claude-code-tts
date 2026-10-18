---
name: say
description: Speak a short spoken briefing out loud on this computer with its built-in text-to-speech voice. Use when the user types /say or $say, or asks you to say something aloud, read something out, or tell them by voice where the work stands. Without text, speaks a briefing (context, outcome, next action and its owner). With text, speaks that text. Do not use for writing files or for voice input.
argument-hint: "[short | long | text to speak]"
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
3. **Next action and owner.** End on what happens next and who does it. If you carry on, say so: "I'll start the docs next." Never end without an owner.

### When the user has to act, give them what they need to act

If the next move is the user's, the briefing must let them decide or act without opening the terminal:

- **A decision:** name the choice, the two or three options with the one trade-off that separates them, and your recommendation with its reason. "Two ways to fix the timeout: raise the limit, quick but hides the slow query, or add an index, about an hour but fixes it. I'd add the index. Your call."
- **Something you need** (a key, a login, access, a file): say exactly what, and where it goes. "I need a Stripe test key in the env file to run the payment tests."
- **An approval:** say what will happen and the risk if any. "I want to drop the old sessions table. It's backed up. Okay to go ahead?"
- **A failure you can't fix alone:** what broke, what you tried, and what you need from them.
- **Someone else must act** (an admin, another team): the user is still the owner. Tell them who to ask and for what: "Can you get an AWS admin to restore the trust policy on the deploy role?"

Make the wait explicit: "I need you to pick", "Okay to go ahead?", "Can you...". The user should never have to infer that the ball is in their court.

Spend the words on the decision, not on the history: cut the context to a few words if needed. If the decision has more than three options or needs real detail, give the recommendation out loud and say the full options are on screen.

Lengths:

| Length | Words | Use |
|---|---|---|
| `short` | up to 15, or up to 20 for a decision | Context and next action only. For a decision: what it is about, the options with their trade-off in a word or two, and your pick. "Reports service timeout: raise the limit, quick but slow, or an index, an hour. I'd index. Your call." |
| normal | up to 35, or up to 50 when the user must decide or act | All three parts. A decision gets options, trade-off and recommendation. |
| `long` | up to 80 | All three parts, plus the one risk the user should know about, and for a decision the options, trade-offs and recommendation in full. |

Stay inside the word limit: aim for about four fifths of it, count the words before you speak, and if you are over, cut history and context first, never the options, the need or the ask. Even in `short`, name the project or task.

Write for the ear:

- Plain spoken sentences. No code, file paths, URLs, markdown, emoji or lists.
- Say identifiers as plain words: "the CI deployer role", not "ci-deployer"; "the sessions table", not "sessions_v1".
- Numbers and symbols as words where needed: "two tests failed", not "2/14 ✗".
- Lead with the user's concern, not your process. Skip "I have completed the task of...".

Good: "In the billing service, the refactor is done and all tests pass. The schema migration is next, and it's your call whether to run it today."
Good, with a decision: "On the signup page, the email check fails for plus addresses. I can loosen the regex, five minutes, or switch to the validator library, safer but a new dependency. I'd use the library. Your call."
Bad: "I made changes to src/billing/invoice.ts and ran npm test." (no outcome, no next step, reads a path aloud)
Bad: "Tests are failing, let me know how you want to proceed." (no detail to decide with, no recommendation)

## 2. Speak it

Run the `speak.sh` script that sits next to this SKILL.md, with the text as one quoted argument. In Claude Code the path is `${CLAUDE_SKILL_DIR}/speak.sh`:

```bash
bash "<this skill's folder>/speak.sh" "In the billing service, the refactor is done and all tests pass. The migration is your call."
```

It returns immediately and the voice plays in the background, so carry on working. If other sessions are speaking, it waits its turn instead of talking over them.

## 3. Show it

Write the same sentence in your reply, so it is on screen too.

If the script says no voice engine was found, tell the user what to install: on Linux `espeak-ng` or `speech-dispatcher`. macOS and Windows (including WSL) need nothing. Voice and speed can be set with the `SAY_VOICE` and `SAY_RATE` environment variables.
