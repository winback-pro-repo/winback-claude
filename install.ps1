# Winback Klaviyo Toolkit — one-command onboarding for strategists (WINDOWS).
#
# Run from a fresh PowerShell window:
#
#   irm https://raw.githubusercontent.com/winback-pro-repo/winback-claude/main/install.ps1 | iex
#
# This script is PUBLIC and contains NO secrets. It installs the tools you need,
# clones the (private) toolkit repo using YOUR GitHub login, builds the Python
# environment, and wires up Claude Code. All credentials are resolved at runtime
# from the 1Password "klaviyo-toolkit" vault — nothing is ever written to a file.
#
# Mac users: use install.sh instead (curl ... | bash).
#
# Before this works, Dean must have granted you three things:
#   1. Access to the "klaviyo-toolkit" 1Password vault
#   2. Access to the winback-pro-repo/winback-klaviyo-toolkit GitHub repo
#   3. A strategist seat in Supabase (he runs seed_identity.py for you)

$ErrorActionPreference = "Stop"

# ── config ────────────────────────────────────────────────────────────────────
$REPO     = "winback-pro-repo/winback-klaviyo-toolkit"
$DEST     = if ($env:WINBACK_DIR) { $env:WINBACK_DIR } else { Join-Path $HOME "Desktop\winback-klaviyo-toolkit" }
$OP_VAULT = "klaviyo-toolkit"
$OP_ITEM  = "Supabase - Klaviyo Toolkit"

# ── pretty output ───────────────────────────────────────────────────────────────
function Step($m) { Write-Host "`n> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "`n[x] $m" -ForegroundColor Red; throw "Setup stopped." }
function Have($c) { return [bool](Get-Command $c -ErrorAction SilentlyContinue) }

# Pull freshly-installed tools onto PATH without needing a new terminal.
function Sync-Path {
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
  $localBin = Join-Path $HOME ".local\bin"
  if (Test-Path $localBin) { $env:Path = "$localBin;$env:Path" }
}

Write-Host "`nWinback Toolkit — strategist setup (Windows)" -ForegroundColor White
Write-Host "Takes ~15-20 min, mostly waiting on installs. You'll do a few browser logins." -ForegroundColor DarkGray

# ── 0. platform ───────────────────────────────────────────────────────────────
Step "Checking your machine"
if ($env:OS -ne "Windows_NT") { Die "This installer is for Windows. On a Mac, use install.sh instead." }
Ok "Windows detected"

# ── 1. winget ───────────────────────────────────────────────────────────────────
Step "Checking winget (the Windows app installer)"

# winget.exe very often EXISTS but isn't resolvable: the WindowsApps execution-alias
# folder isn't on PATH, or the App Installer package isn't registered for this user.
# Try to fix both automatically before giving up.
function Resolve-Winget {
  if (Have winget) { return $true }
  $apps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
  if (Test-Path (Join-Path $apps "winget.exe")) {
    $env:Path = "$apps;$env:Path"
    if (Have winget) { return $true }
  }
  return $false
}

if (-not (Resolve-Winget)) {
  Warn "winget isn't on PATH — trying to enable it automatically..."
  # Re-register the App Installer package (fixes 'installed but not registered for this user').
  try {
    Get-AppxPackage Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | ForEach-Object {
      Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
    }
  } catch {}
  Start-Sleep -Seconds 2
  Sync-Path
  $null = Resolve-Winget
}

if (-not (Have winget)) {
  Die @"
winget (the Windows app installer) isn't available and I couldn't enable it automatically.
Quickest fix: open the Microsoft Store, search for 'App Installer', and click Install or Update.
Then close this window, open a fresh PowerShell, and paste the install command again.
(App Installer is the Microsoft app that provides 'winget'.)
If the Microsoft Store is blocked on this PC, tell Dean — we'll install the tools another way.
"@
}
Ok "winget ready"

# ── 2. core tools ─────────────────────────────────────────────────────────────
Step "Installing core tools (git, GitHub CLI, Python 3.11, 1Password CLI)"
function Winget-Ensure($cmd, $id, $label) {
  if (Have $cmd) { Ok "$label already installed"; return }
  Warn "Installing $label..."
  winget install --id $id -e --source winget --accept-source-agreements --accept-package-agreements
  Sync-Path
  if (Have $cmd) { Ok "$label installed" } else { Warn "$label installed — may need a new terminal to appear on PATH." }
}
Winget-Ensure git    "Git.Git"                 "git"
Winget-Ensure gh     "GitHub.cli"              "GitHub CLI"
Winget-Ensure python "Python.Python.3.11"      "Python 3.11"
Winget-Ensure op     "AgileBits.1Password.CLI" "1Password CLI"
Sync-Path

# ── 3. Claude Code ──────────────────────────────────────────────────────────────
Step "Claude Code"
if (-not (Have claude)) {
  Warn "Installing Claude Code..."
  try { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression } catch { Warn "Claude Code install hit a snag: $_" }
  Sync-Path
}
if (Have claude) { Ok "Claude Code installed" } else { Warn "Claude Code installed — open a new terminal later for the 'claude' command." }

# ── 4. GitHub login ─────────────────────────────────────────────────────────────
Step "GitHub login (so we can download the toolkit)"
gh auth status 2>$null
if ($LASTEXITCODE -eq 0) {
  Ok "Already logged into GitHub"
} else {
  Warn "Let's log you into GitHub. Choose: GitHub.com > HTTPS > Login with a web browser."
  gh auth login
  gh auth status 2>$null
  if ($LASTEXITCODE -eq 0) { Ok "GitHub login confirmed" } else { Die "GitHub login didn't complete. Re-run the command to try again." }
}

# ── 5. 1Password CLI ────────────────────────────────────────────────────────────
Step "1Password (where your credentials live — nothing is copied to your laptop)"
op whoami 2>$null
if ($LASTEXITCODE -eq 0) {
  Ok "1Password CLI connected"
} else {
  Write-Host "`n  Open the 1Password DESKTOP app > Settings > Developer > check" -ForegroundColor Yellow
  Write-Host "  'Integrate with 1Password CLI'. Keep the app unlocked." -ForegroundColor Yellow
  Read-Host "  Press Enter when done"
  op whoami 2>$null
  if ($LASTEXITCODE -ne 0) { Warn "Still not connected — trying interactive sign-in..."; try { op signin } catch {} }
  op whoami 2>$null
  if ($LASTEXITCODE -eq 0) { Ok "1Password CLI connected" } else { Warn "1Password CLI not connected yet — we'll catch this at the connection test." }
}
# Verify vault access (cheap, non-fatal read).
op read "op://$OP_VAULT/$OP_ITEM/SUPABASE_URL" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { Ok "Vault access confirmed" } else { Warn "Couldn't read the '$OP_VAULT' vault. If the rest fails, ask Dean to grant you vault access." }

# ── 6. clone the toolkit ────────────────────────────────────────────────────────
Step "Downloading the toolkit"
if (Test-Path (Join-Path $DEST ".git")) {
  Ok "Already cloned at $DEST — pulling latest"
  git -C $DEST pull --ff-only
  if ($LASTEXITCODE -ne 0) { Warn "Couldn't fast-forward; you may have local changes. Not fatal." }
} else {
  $parent = Split-Path $DEST -Parent
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  gh repo clone $REPO $DEST
  if ($LASTEXITCODE -ne 0) { Die "Couldn't clone the repo. Ask Dean to confirm you have access to $REPO." }
  Ok "Cloned to $DEST"
}
Set-Location $DEST

# ── 7. Python environment ───────────────────────────────────────────────────────
Step "Building the Python environment (isolated; won't touch the rest of your PC)"
if (-not (Test-Path ".venv")) {
  if (Have py) { py -3.11 -m venv .venv } else { python -m venv .venv }
}
$venvPy = Join-Path $DEST ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) { Die "Python environment didn't build. Open a new terminal and re-run this command." }
& $venvPy -m pip install --quiet --upgrade pip
& $venvPy -m pip install --quiet -r requirements.txt
Ok "Dependencies installed"
# Headless Chromium for email/board rendering (Figma boards, audit apps).
& $venvPy -m playwright install chromium
if ($LASTEXITCODE -eq 0) { Ok "Browser engine for rendering installed" } else { Warn "Chromium didn't install — fix later with: .venv\Scripts\python -m playwright install chromium" }

# ── 8. connection test ──────────────────────────────────────────────────────────
Step "Testing the Supabase connection"
& $venvPy scripts/test_supabase_connection.py
if ($LASTEXITCODE -eq 0) {
  Ok "Connection works — you're set up"
} else {
  Warn "Connection test didn't pass. Most common fix: make sure the 1Password desktop app is unlocked, then re-run:"
  Write-Host "    cd `"$DEST`"; .venv\Scripts\python scripts\test_supabase_connection.py" -ForegroundColor DarkGray
  Warn "If it still fails, send Dean the error above — don't keep guessing."
}

# ── done ──────────────────────────────────────────────────────────────────────
Write-Host "`nSetup complete." -ForegroundColor Green
Write-Host @"

What to do next
  1. Open this folder in Cursor:   $DEST
  2. In the terminal there, run:   claude
     - First time: it opens a browser to log into your Claude account.
     - When it asks to trust the folder and enable its tools, say yes.
  3. Connect your Claude connectors (Klaviyo, Supabase, Slack, Figma, Drive...)
     once in your Claude account settings - those are tied to you, not the repo.
  4. Try a command inside Claude:  /list-clients

Day-to-day
  Always work inside $DEST. Open Claude Code there and the Winback skills
  (/run-audit, /biweekly, /sync-client, ...) are ready. Keep the 1Password
  desktop app unlocked while you work.

If something breaks
  9 times out of 10 it's the 1Password app being locked. Unlock it and retry.
  Still stuck after ~5 min? Send Dean the exact error.
"@
