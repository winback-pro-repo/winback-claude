#!/usr/bin/env bash
#
# Winback Klaviyo Toolkit — one-command onboarding for strategists.
#
# Run from a fresh terminal (Cursor's terminal is fine):
#
#   curl -fsSL https://raw.githubusercontent.com/winback-pro-repo/winback-claude/main/install.sh | bash
#
# This script is PUBLIC and contains NO secrets. It installs the tools you need,
# clones the (private) toolkit repo using YOUR GitHub login, builds the Python
# environment, and wires up Claude Code. All credentials are resolved at runtime
# from the 1Password "klaviyo-toolkit" vault — nothing is ever written to a file.
#
# Before this works, Dean must have granted you three things:
#   1. Access to the "klaviyo-toolkit" 1Password vault
#   2. Access to the winback-pro-repo/winback-klaviyo-toolkit GitHub repo
#   3. A strategist seat in Supabase (he runs seed_identity.py for you)
#
set -euo pipefail

# ── config ──────────────────────────────────────────────────────────────────
REPO="winback-pro-repo/winback-klaviyo-toolkit"
DEST="${WINBACK_DIR:-$HOME/Desktop/winback-klaviyo-toolkit}"
OP_VAULT="klaviyo-toolkit"
OP_ITEM="Supabase - Klaviyo Toolkit"

# ── pretty output ───────────────────────────────────────────────────────────
bold=$'\033[1m'; green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; dim=$'\033[2m'; reset=$'\033[0m'
step() { printf "\n${bold}▸ %s${reset}\n" "$1"; }
ok()   { printf "  ${green}✓ %s${reset}\n" "$1"; }
warn() { printf "  ${yellow}! %s${reset}\n" "$1"; }
die()  { printf "\n${red}✗ %s${reset}\n" "$1" >&2; exit 1; }
pause(){ printf "\n${yellow}%s${reset}\n" "$1"; read -r -p "  Press Return when done… " _ </dev/tty; }

have() { command -v "$1" >/dev/null 2>&1; }

printf "\n${bold}Winback Toolkit — strategist setup${reset}\n"
printf "${dim}Takes ~15–20 min, mostly waiting on installs. You'll do a few browser logins.${reset}\n"

# ── 0. platform ─────────────────────────────────────────────────────────────
step "Checking your machine"
[ "$(uname -s)" = "Darwin" ] || die "This installer supports macOS only. Ping Dean if you're on Windows/Linux."
ok "macOS detected"

# ── 1. Homebrew ─────────────────────────────────────────────────────────────
step "Homebrew (the macOS package installer)"
if ! have brew; then
  warn "Homebrew isn't installed. Installing it now (you may be asked for your Mac password)…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon puts brew in /opt/homebrew; make it usable in this shell.
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
fi
have brew || die "Homebrew install didn't finish. Re-run this script, or see https://brew.sh"
ok "Homebrew ready"

# ── 2. core tools ───────────────────────────────────────────────────────────
step "Installing core tools (git, gh, Python 3.11, 1Password CLI)"
have git              || brew install git
have gh               || brew install gh
have python3.11       || brew install python@3.11
have op               || brew install --cask 1password-cli
ok "Tools installed"

# ── 3. Claude Code ──────────────────────────────────────────────────────────
step "Claude Code"
if ! have claude; then
  warn "Installing Claude Code…"
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
fi
have claude && ok "Claude Code installed" || warn "Claude Code installed — you may need to open a new terminal for the 'claude' command."

# ── 4. GitHub login ─────────────────────────────────────────────────────────
step "GitHub login (so we can download the toolkit)"
if gh auth status >/dev/null 2>&1; then
  ok "Already logged into GitHub"
else
  warn "Let's log you into GitHub. Choose: GitHub.com → HTTPS → Login with a web browser."
  gh auth login </dev/tty || die "GitHub login didn't complete. Re-run the script to try again."
  gh auth status >/dev/null 2>&1 && ok "GitHub login confirmed" || die "GitHub login not confirmed."
fi

# ── 5. 1Password CLI ────────────────────────────────────────────────────────
step "1Password (where your credentials live — nothing is copied to your laptop)"
if op whoami >/dev/null 2>&1; then
  ok "1Password CLI connected"
else
  pause "Open the 1Password DESKTOP app → Settings → Developer → check 'Integrate with 1Password CLI' (and Touch ID if offered). Keep the app unlocked."
  op whoami >/dev/null 2>&1 || { warn "Still not connected — trying interactive sign-in…"; op signin </dev/tty || true; }
  op whoami >/dev/null 2>&1 && ok "1Password CLI connected" || warn "1Password CLI not connected yet — we'll catch this at the connection test."
fi
# Verify the strategist actually has the vault (cheap, non-fatal read).
if op read "op://$OP_VAULT/$OP_ITEM/SUPABASE_URL" >/dev/null 2>&1; then
  ok "Vault access confirmed"
else
  warn "Couldn't read the '$OP_VAULT' vault. If the rest fails, ask Dean to grant you vault access."
fi

# ── 6. clone the toolkit ────────────────────────────────────────────────────
step "Downloading the toolkit"
if [ -d "$DEST/.git" ]; then
  ok "Already cloned at $DEST — pulling latest"
  git -C "$DEST" pull --ff-only || warn "Couldn't fast-forward; you may have local changes. Not fatal."
else
  mkdir -p "$(dirname "$DEST")"
  gh repo clone "$REPO" "$DEST" || die "Couldn't clone the repo. Ask Dean to confirm you have access to $REPO."
  ok "Cloned to $DEST"
fi
cd "$DEST"

# ── 7. Python environment ───────────────────────────────────────────────────
step "Building the Python environment (isolated; won't touch the rest of your Mac)"
PY="$(command -v python3.11 || command -v python3)"
[ -d .venv ] || "$PY" -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r requirements.txt
ok "Dependencies installed ($(python -m pip list 2>/dev/null | wc -l | tr -d ' ') packages)"
# Headless Chromium for email/board rendering (Figma boards, audit apps).
python -m playwright install chromium >/dev/null 2>&1 \
  && ok "Browser engine for rendering installed" \
  || warn "Chromium didn't install — email/board rendering may not work. Fix later with: python -m playwright install chromium"

# ── 8. connection test ──────────────────────────────────────────────────────
step "Testing the Supabase connection"
if python scripts/test_supabase_connection.py; then
  ok "Connection works — you're set up"
else
  warn "Connection test didn't pass. Most common fix: make sure the 1Password desktop app is unlocked, then re-run:"
  printf "    ${dim}cd %s && source .venv/bin/activate && python scripts/test_supabase_connection.py${reset}\n" "$DEST"
  warn "If it still fails, send Dean the error above — don't keep guessing."
fi

# ── done ────────────────────────────────────────────────────────────────────
printf "\n${green}${bold}Setup complete.${reset}\n"
cat <<EOF

${bold}What to do next${reset}
  1. Open this folder in Cursor:   ${dim}$DEST${reset}
  2. In the terminal there, run:   ${dim}claude${reset}
     • First time: it opens a browser to log into your Claude account.
     • When it asks to trust the folder and enable its tools → say yes.
  3. Connect your Claude connectors (Klaviyo, Supabase, Slack, Figma, Drive…)
     once in your Claude account settings — those are tied to you, not the repo.
  4. Try a command inside Claude:  ${dim}/list-clients${reset}

${bold}Day-to-day${reset}
  Always work inside ${dim}$DEST${reset}. Open Claude Code there and the Winback
  skills (/run-audit, /biweekly, /sync-client, …) are ready. Keep the 1Password
  desktop app unlocked while you work.

${bold}If something breaks${reset}
  9 times out of 10 it's the 1Password app being locked. Unlock it and retry.
  Still stuck after ~5 min? Send Dean the exact error.
EOF
