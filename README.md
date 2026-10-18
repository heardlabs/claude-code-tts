<div align="center">

<img src=".claude-plugin/icon.png" width="88" alt="">

# claude-code-tts: a /say skill for Claude Code and Codex

**Text-to-speech for your coding agent. Type `/say` and hear where the work stands.**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-skill_%2B_plugin-d97757)](#install)
[![Codex](https://img.shields.io/badge/Codex-skill-111111)](#install)
![macOS · Linux · Windows](https://img.shields.io/badge/macOS_%C2%B7_Linux_%C2%B7_Windows-supported-555555)
![No API key](https://img.shields.io/badge/API_key-none-2ea44f)

</div>

```text
> /say
speaking: Billing refactor is done and all tests pass. Next step is the migration, your call.

> /say the build is green, going for coffee
speaking: the build is green, going for coffee
```

## Why

Your agent finished five minutes ago and you were looking at another window. `/say` lets Claude Code (`/say`) or Codex (`$say`) tell you out loud, in a sentence or two, what happened and what comes next. Ask for it whenever you like, or tell the agent "say it out loud when the tests finish".

## Features

- **Spoken status in one line.** Without text, the agent sums up the project, the outcome (done, failed, blocked) and the next step with who owns it, in 40 words or fewer.
- **Says anything you give it.** `/say <text>` reads your text as is.
- **Never blocks the agent.** Speech plays in the background, and the command returns at once.
- **Parallel sessions take turns.** Several agents speaking at once queue up instead of talking over each other.
- **On screen too.** The same sentence appears in the reply, so you can read it later.
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
Install the skill above and type `/say`. Claude writes a short spoken update and your computer reads it aloud.

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
