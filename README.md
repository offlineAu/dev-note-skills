# dev-note-skills

Personal Codex/Claude skills, laid out so Codex's bundled `skill-installer` can
install them directly from GitHub.

## Install into Codex

```bash
python "$CODEX_HOME/skills/.system/skill-installer/scripts/install-skill-from-github.py" \
  --repo offlineAu/dev-note-skills --path skills/dev-note
```

On Windows, the line above fails in Command Prompt: `$CODEX_HOME` and the `\`
line break are bash syntax. Use one line instead.

PowerShell:

```powershell
python "$env:USERPROFILE\.codex\skills\.system\skill-installer\scripts\install-skill-from-github.py" --repo offlineAu/dev-note-skills --path skills/dev-note
```

Command Prompt:

```bat
python "%USERPROFILE%\.codex\skills\.system\skill-installer\scripts\install-skill-from-github.py" --repo offlineAu/dev-note-skills --path skills/dev-note
```

If `CODEX_HOME` is set to another folder, use it in place of
`%USERPROFILE%\.codex`.

Or just ask Codex: *"install dev-note from offlineAu/dev-note-skills"* — the
`skill-installer` skill handles it.

Install several at once:

```bash
... --repo offlineAu/dev-note-skills --path skills/dev-note skills/mirror-3-term
```

The installer writes to `$CODEX_HOME/skills/<skill-name>` (default
`~/.codex/skills`) and **aborts if that directory already exists** — remove or
rename the existing copy to reinstall. Skills become available on the next turn;
a fresh Codex start is the reliable way to pick up new ones.

## Keep skills across Codex accounts (Windows)

Each Codex account has its own skills folder, so switching accounts hides skills
installed under the previous one. From a clone of this repo, run:

```powershell
powershell -File scripts\sync-skills.ps1
```

It copies every skill into `~/.codex`, each Orca account home, and the Orca
shared runtime, replacing older copies of the same skills. Run it again after
adding a new account or pulling skill updates. Add `-WhatIf` to preview, or
`-Skill dev-note` to sync just one.

## Install into Claude Code

Claude Code reads `~/.claude/skills/<name>/`, so copy the folder:

```bash
cp -r skills/dev-note ~/.claude/skills/dev-note
```

## Invoking

- **Codex** — skills are not slash commands. Use `$dev-note`, or describe the
  task and let the description trigger it.
- **Claude Code** — `/dev-note`.

## Skills

| Skill | What it does |
| --- | --- |
| `dev-note` | Writes a dev note for the latest fix: problem, root cause, the change, verification. |
| `mirror-3-term` | Mirrors K-12 three-term/periodic grading, dynamic ECR, and SHS Cluster/Plotting/Subject Picking between sibling repos. |

## Layout

Each skill is a directory under `skills/` containing `SKILL.md` (YAML
frontmatter limited to `name`, `description`, `metadata`, `allowed-tools`,
`license`) and an optional `agents/openai.yaml` giving Codex its display name,
blurb, and default prompt.

Validate before committing:

```bash
python "$CODEX_HOME/skills/.system/skill-creator/scripts/quick_validate.py" skills/dev-note
```
