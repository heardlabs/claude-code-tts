# claude-code-tts: a /say skill for Claude Code and Codex

Text-to-speech for Claude Code and Codex in one small skill. Type `/say` (Claude Code) or `$say` (Codex) and the agent tells you out loud where the work stands, in a sentence or two. Give it text and it says that instead:

```
/say
/say the build is green, going for coffee
```

The agent can also use it on its own when you ask, for example "say it out loud when the tests finish".

It uses the voice your computer already has, so there is nothing to sign up for and no API key:

| System | Engine |
|---|---|
| macOS | `say` (built in) |
| Linux | `spd-say`, `espeak-ng` or `espeak` (install one: `sudo apt install espeak-ng`) |
| Windows / WSL | PowerShell `System.Speech` (built in) |

Speech plays in the background, so the agent never waits for it.

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

## Options

Set these in your shell profile:

- `SAY_VOICE`: voice name, for example `Samantha` on macOS (`say -v '?'` lists them) or `en-us` for espeak.
- `SAY_RATE`: words per minute, for example `200`.

The script is `skills/say/speak.sh`. You can call it from anything: `echo "deploy done" | bash speak.sh`.

## Want it to speak by itself?

`/say` speaks when you or the agent asks. To hear an update every time the agent finishes, without asking:

- **DIY:** a Claude Code `Stop` hook that pipes a short summary into a TTS command. There is a walk-through in [Make Claude Code talk back with a text-to-speech Stop hook](https://dev.to/sodiumsun/make-claude-code-talk-back-with-a-text-to-speech-stop-hook-5cc3).
- **Heard:** this skill comes from the team behind [Heard](https://heard.dev/?utm_source=github&utm_medium=organic&utm_campaign=say-skill), the voice layer for coding agents on macOS. Heard follows your Claude Code and Codex sessions and tells you in a sentence or two when an agent finishes, fails or needs your approval. Its engine is [open source (Apache 2.0)](https://github.com/heardlabs/heard) and runs fully local with Kokoro text-to-speech.

## License

MIT
