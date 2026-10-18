<div align="center">

<img src=".claude-plugin/icon.png" width="88" alt="">

# claude-code-tts: a /say skill for Claude Code and Codex

**Spoken briefings from your coding agent. Type `/say` and hear what this is, how it went, and who moves next.**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-skill_%2B_plugin-d97757)](#install)
[![Codex](https://img.shields.io/badge/Codex-skill-111111)](#install)
![macOS · Linux · Windows](https://img.shields.io/badge/macOS_%C2%B7_Linux_%C2%B7_Windows-supported-555555)
![No API key](https://img.shields.io/badge/API_key-none-2ea44f)

</div>

```text
> /say
speaking: In the billing service, the refactor is done and all tests pass.
          The schema migration is next, and it's your call whether to run it today.

> /say short
speaking: Billing refactor done, migration is your call.
```

## Not just text-to-speech: a briefing format

Reading an agent's reply aloud word by word is noise. `/say` makes the agent write a briefing for the ear first, always in the same three parts:

| Part | What it says | Example |
|---|---|---|
| **1. Context** | Which project or task, so you know which session is talking | "In the billing service," |
| **2. Outcome** | Done, failed, blocked or still going, plus the one fact that matters | "the refactor is done and all tests pass." |
| **3. Next action + owner** | What happens next and who does it. Never ends without an owner | "The migration is your call." / "I'll start the docs next." |

No code, file paths, URLs or markdown are read aloud. Numbers come out as words ("two tests failed", not "2/14").

Pick the length:

| Command | Length | What you get |
|---|---|---|
| `/say short` | up to 15 words | Context and next action |
| `/say` | up to 35 words | All three parts |
| `/say long` | up to 70 words | All three parts, plus the one risk or decision you should know about |
| `/say <text>` | your text | Reads your text as is |

Codex uses `$say` the same way. You can also tell the agent "say it out loud when the tests finish".

## Features

- **A templated briefing, not a transcript.** Context, outcome, next action and owner, every time.
- **Three lengths.** `short`, normal and `long`, so a glance and a full update both work.
- **Parallel sessions take turns.** Several agents speaking at once queue up instead of talking over each other, and the context line tells you which one is talking.
- **Never blocks the agent.** Speech plays in the background, and the command returns at once.
- **On screen too.** The same briefing appears in the reply, so you can read it later.
- **Nothing to sign up for.** It uses the voice your computer already has. No account, no API key, no network.

## Install

**Claude Code and Codex, as a personal skill** (gives you `/say` and `$say`):

```bash
git clone https://github.com/heardlabs/claude-code-tts
mkdir -p ~/.claude/skills ~/.agents/skills
cp -r claude-code-tts/skills/say ~/.claude/skills/
cp -r claude-code-tts/skills/say ~/.agents/skills/
```

**Claude Code, as a plugin** (the command is then `/say:say`):

```bash
claude plugin marketplace add heardlabs/claude-code-tts
claude plugin install say@claude-code-tts
```

Then try `/say hello`.

## Supported systems

| System | Voice engine | Setup |
|---|---|---|
| macOS | `say` | Built in |
| Linux | `spd-say`, `espeak-ng` or `espeak` | `sudo apt install espeak-ng` |
| Windows / WSL | PowerShell `System.Speech` | Built in |

## Options

Set these in your shell profile:

| Variable | What it does | Example |
|---|---|---|
| `SAY_VOICE` | Voice name (`say -v '?'` lists them on macOS) | `Samantha`, `en-us` |
| `SAY_RATE` | Words per minute | `200` |

The script is [`skills/say/speak.sh`](skills/say/speak.sh) and works on its own too: `echo "deploy done" | bash speak.sh`.

## FAQ

**How do I make Claude Code talk out loud?**
Install the skill above and type `/say`. Claude writes a short spoken briefing (context, outcome, next action and owner) and your computer reads it aloud.

**How is this different from piping Claude's reply into a TTS command?**
A raw reply read aloud is long and full of code and paths. `/say` has the agent write a few words for the ear in a fixed format first, so you can tell at once which session it is, how it went, and whether it needs you.

**Does it work with Codex?**
Yes. Copy the skill into `~/.agents/skills` and type `$say` in Codex.

**Does it send my code anywhere?**
No. The text goes straight to your computer's built-in voice. Nothing leaves the machine.

**Can it speak automatically every time the agent finishes?**
`/say` speaks when you or the agent asks. For automatic updates, see the next section.

## Want it to speak by itself?

- **DIY:** a Claude Code `Stop` hook that pipes a short summary into a TTS command. There is a walk-through in [Make Claude Code talk back with a text-to-speech Stop hook](https://dev.to/sodiumsun/make-claude-code-talk-back-with-a-text-to-speech-stop-hook-5cc3).
- **Heard:** this skill comes from the team behind [Heard](https://heard.dev/?utm_source=github&utm_medium=organic&utm_campaign=say-skill), the voice layer for coding agents on macOS. Heard follows your Claude Code and Codex sessions and tells you in a sentence or two when an agent finishes, fails or needs your approval. Its engine is [open source (Apache 2.0)](https://github.com/heardlabs/heard) and runs fully local with Kokoro text-to-speech.

## License

[MIT](LICENSE)
