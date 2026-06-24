# Winback Toolkit — strategist setup

One command sets up everything you need to work with the Winback Klaviyo toolkit
in Claude Code, from a fresh Mac **or Windows PC**.

## Run this

Open a terminal (Cursor's built-in terminal is fine) and paste the line for your
computer.

**On a Mac** (Terminal / Cursor terminal — this is `zsh` or `bash`):

```bash
curl -fsSL https://raw.githubusercontent.com/winback-pro-repo/winback-claude/main/install.sh | bash
```

**On Windows** (PowerShell — the blue terminal; this is Cursor's default on Windows):

```powershell
irm https://raw.githubusercontent.com/winback-pro-repo/winback-claude/main/install.ps1 | iex
```

> Not sure which you're on? If pasting the Mac line gives a red `bash : ...
> CommandNotFoundException`, you're on Windows — use the PowerShell line instead.

It takes ~15–20 minutes, mostly waiting on installs. You'll do a few quick
browser logins along the way (GitHub, 1Password, Claude). The script tells you
exactly what to click.

## Before it works

Dean needs to have granted you three things first — ask him if you're not sure:

1. Access to the **klaviyo-toolkit** vault in Winback's 1Password
2. Access to the **winback-klaviyo-toolkit** GitHub repo
3. A strategist seat in the toolkit's database

## What the command does

- Installs the tools you need (Homebrew, git, GitHub CLI, 1Password CLI, Python, Claude Code)
- Logs you into GitHub and 1Password
- Downloads the toolkit
- Builds an isolated Python environment
- Tests the connection so you know it worked

**No passwords or keys are ever saved to your laptop.** Everything is read
securely from 1Password the moment it's needed — which is why the 1Password
desktop app needs to be open and unlocked while you work.

## After setup

1. Open the toolkit folder in Cursor (the script prints the path)
2. Run `claude` in the terminal there → log into your Claude account when prompted → say **yes** to trusting the folder
3. Connect your Claude connectors (Klaviyo, Supabase, Slack, Figma, Drive, …) once in your Claude account settings
4. Try a command: `/list-clients`

The Winback skills (`/run-audit`, `/biweekly`, `/sync-client`, `/email-qa`, …)
are ready whenever you open Claude Code in that folder.

### Optional: use the skills anywhere

To use the Winback skills outside the toolkit folder too, install the plugin
once inside Claude Code:

```
/plugin marketplace add winback-pro-repo/winback-klaviyo-toolkit
/plugin install winback-toolkit@winback
```

(Inside the toolkit folder you don't need this — the skills are already there as
`/run-audit` etc. The plugin just makes them available globally as
`/winback-toolkit:run-audit`.)

## If something breaks

Nine times out of ten it's the 1Password desktop app being **locked** — unlock
it and retry. To re-run the connection test:

```bash
cd ~/Desktop/winback-klaviyo-toolkit && source .venv/bin/activate && python scripts/test_supabase_connection.py
```

Still stuck after ~5 minutes? Send Dean the exact error message instead of
guessing.
