# Installing Superpowers-BD for Codex

Prefer the native Codex plugin path when available.

## Native Plugin

```bash
mkdir -p ~/.codex/plugins
git clone https://github.com/schlenks/superpowers-bd.git ~/.codex/plugins/superpowers-bd
codex plugin marketplace add ~/.codex/plugins/superpowers-bd
```

Then install or enable `superpowers-bd` in Codex and restart Codex so the bundled skills load.

## Legacy Bootstrap Fallback

Use this only if native plugin installation is unavailable.

```bash
mkdir -p ~/.codex
git clone https://github.com/schlenks/superpowers-bd.git ~/.codex/superpowers
mkdir -p ~/.codex/skills
```

Add this to `~/.codex/AGENTS.md`:

```markdown
## Superpowers System

<EXTREMELY_IMPORTANT>
You have superpowers. RIGHT NOW run: `~/.codex/superpowers/.codex/superpowers-codex bootstrap` and follow the instructions it returns.
</EXTREMELY_IMPORTANT>
```

Verify:

```bash
~/.codex/superpowers/.codex/superpowers-codex find-skills
```
