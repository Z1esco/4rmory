---
name: terminal-cli-craft
description: Build or overhaul a polished, simple, safe terminal CLI or interactive TUI menu in any language (Bash, Python, Node, Go, Rust). Use when creating a new CLI tool, redesigning an existing one's UX (banner, menus, numbering, prompts, colours, exit behaviour), adding a shareable catalog/registry with self-update, adding install/scan safety, or making a CLI repo look professional (README, SECURITY, CHANGELOG, .gitignore). Triggers on "build a CLI", "improve my CLI", "make the CLI look better", "CLI UX", "interactive menu", "banner", "self-update", "make the repo professional".
---

# Terminal CLI Craft

A field-tested recipe for CLIs that feel simple, look professional and stay safe.
Language-agnostic. Examples in `references/snippets.md` are Bash; translate the
idea, not the syntax.

Work in this order: **Audit → Architecture → UX → Safety → Docs → Test → Ship.**
Do not polish UI before the structure is right.

## 0. Audit the existing CLI first (if one exists)

Run it. Walk every menu path by hand. Note, with evidence:
- Where does a blank Enter, a typo, Ctrl-C or Ctrl-D take the user? (Any surprise exit is a bug.)
- How many keystrokes to do the top 3 tasks? Anything deeper than 3 levels is too deep.
- Labels: inconsistent case, jargon, abbreviations, unexplained flags.
- Output: does it break when piped (`| cat`), with `NO_COLOR=1`, or in an 80-column terminal?
- Secrets/paths/emails hard-coded or committed (scan full git history, not just HEAD).
Write the findings down before changing anything.

## 1. Architecture

- **Thin entry point.** The executable only resolves its real location (follow symlinks), loads modules, calls `main`. All logic lives in modules.
- **One concern per module:** `core` (paths, config, validation), `theme` (colours), `ui` (banner, menus, prompts, messages), domain modules (catalog, install, scan…), `cli` (argument dispatch, help, menu loop).
- **Namespaced functions** (`xx_` prefix or a package) so nothing collides.
- **Every menu action is also a subcommand.** `tool search foo`, `tool install bar -y`. The menu is a front-end over the same functions — scriptable, testable.
- **User data out of the repo.** Use XDG dirs (`~/.local/share/<tool>`, `~/.config/<tool>`). Repo = code + shipped data only. Gitignore any local state that could land in the tree.
- **Layered data:** shared data (in repo) + personal overlay (user dir; same id overrides; a "hidden" list for removals) merged at read time. Users customise without forking; updates never clobber their edits.
- **Maintainer mode** (flag file or env var) switches add/edit/remove to write the shared data, plus a `publish` command (export docs → commit → pull --rebase → push).
- **Self-update via git:** `update` = `git pull --rebase --autostash` on the install dir, then diff ids to show what's new. A cheap startup check (`git fetch` throttled to every few hours, with a timeout) shows a "★ New items available" badge.
- **Install script** just symlinks the entry into `~/.local/bin`. No root.
- Keep a target runtime floor (e.g. Bash 3.2 for macOS, Python 3.9) and stick to it.

## 2. UX rules (the ones users actually notice)

**Entry**
- Centred banner (figlet or a pre-rendered fallback file in `assets/`), optional gradient, one-line tagline with version. Skip the banner when not a TTY or when a subcommand was given.

**Menus**
- Group items under short section headers (e.g. FIND · INSTALL · YOUR LIST · SAFETY & HELP). Max ~10 items total.
- Numbered badges: compact and consistent width. On Nerd Fonts, round caps (U+E0B6 / U+E0B4) around a coloured digit look best; fall back to ` 1 ` bold, and to `(1)` with no colour. Detect the font once at startup (e.g. `fc-list | grep -i nerd`), allow an env override (`TOOL_BADGES=round|plain`). Avoid ① circled digits — they render small and oval.
- `0 Exit` always last. Say **Exit**, not Quit.
- One hint line under the menu: "Type a number and press Enter · Type Exit anytime to leave".
- Pick-by-number from results, then an action sub-menu (Install / Scan / Edit / Remove). Never make users retype names or ids.
- If `fzf` is present, use it for long lists; numbered fallback otherwise.

**Input**
- **Blank Enter never exits and never redraws the whole screen** — just re-prompt.
- Invalid input → one short error line, re-prompt. Don't clear the screen.
- **`exit`/`quit` typed at ANY prompt, any depth, leaves cleanly** with one goodbye line. (Nested subshells: see snippets for the signal trick.)
- In sub-pickers, blank Enter = Back (label the prompt: "(1-8, Enter = Back)").
- Destructive actions confirm, default No. `-y` flag skips confirms for scripting.

**Text**
- Capitalise the first letter of every label, title, status, kind. Plain verbs: Search, Install, Update, Remove.
- Messages have four levels with icons: info `›`, ok `✔`, warn `!`, error `✖`. Errors say what to do next.
- Descriptions are one plain sentence a non-expert understands. No marketing words.

**Output hygiene**
- Honour `NO_COLOR` and non-TTY (no ANSI codes when piped).
- Width from `tput cols`/`$COLUMNS`, fallback 80. Build horizontal rules with a loop or string repeat — never byte tools (`tr`) on multibyte characters.
- `help` = a "Getting started" block (3 commands) then grouped command list. `doctor` = checks deps and paths and says how to fix each.

## 3. Safety

- Validate every external value: ids `[a-z0-9-]`, URLs https + allow-listed hosts + no shell metacharacters, strip tabs/newlines from fields stored in TSV/CSV.
- Never execute downloaded code. Clone shallow into a managed dir, inspect, then link/copy.
- Never overwrite files the tool didn't create; track what it installed in a manifest.
- If installing third-party content: **scan before install**. Use more than one scanner; mark *danger* (block unless `--force`) only when independent scanners agree; *warn* asks "Install anyway?"; record verdicts in a local log. A built-in grep check is advisory, used only when no real scanner is installed.
- No telemetry. No sending user content anywhere without an explicit command.
- Before going public: regex-scan files **and full git history** for keys, tokens, emails, home paths.

## 4. Docs & repo polish

- **README:** centred logo (SVG) + banner image, shields badges (language, version, license, item count), one-line pitch, Quick start (3 commands), a menu preview in a code block, Requirements, Commands table, a **Help section of collapsible `<details>`** (install, setup, update, add/edit, uninstall, tips), project layout, footer links.
- **SECURITY.md:** a table of protections (what / how), honest limits, supported versions, how to report.
- **CHANGELOG.md** (Keep a Changelog, semver) · **CONTRIBUTING.md** (how to add items, code rules) · **LICENSE**.
- **.gitignore:** OS/editor junk, secrets (`.env`, `*.pem`, `*.key`, `id_rsa*`, `credentials*.json`), the tool's local state, temp files, language caches.

## 5. Test the real flow

- Piped scripted input: `printf '1\nfoo\n\n0\n' | ./tool` — walk every menu, including blank and junk input.
- Real TTY capture (pty) to verify actual ANSI bytes and glyphs; `NO_COLOR=1 ./tool | cat` for the plain path.
- Exit at every depth: main menu, inside search, inside setup, inside a picker, inside a confirm.
- Self-update end-to-end: clone into a temp dir with a **local bare repo** as `origin`, publish from one clone, `update` in another, confirm the "new" badge and list.
- Render glyphs you're unsure of to a PNG with the target font before shipping.
- Lint (`shellcheck`, `ruff`, `eslint`…) clean.

## 6. Ship

Bump version in one place, update CHANGELOG + README badges, commit (conventional message), push, merge to main. Tell the user the one-line update command.

## Gotchas (each cost real time)

- `pkill -f pattern` kills your own shell if the pattern is in its command line. Kill by PID.
- Exiting from a nested subshell (`$(...)`, pipelines) only exits that subshell. Signal the main PID (USR1 trap) and stop helper subshells with SIGPIPE — SIGTERM prints "Terminated" noise.
- Per-call feature detection inside `$(...)` reruns every time; detect once at startup into a variable.
- `pipx install` can hang for many minutes; `uv tool install` is faster and reliable.
- Scanners often have separate single-item vs multi-item modes (e.g. root manifest vs `scan-all --recursive`); pick by layout or you get "unreadable".
- A single HIGH finding from one scanner blocks too much legit content; use the scanner's own recommendation field plus agreement.
- `git commit` in fresh environments fails without `user.name`/`user.email`; set repo-local from existing history.
- Logs written inside the repo get committed by accident. Write them to the data dir.

See `references/snippets.md` for drop-in implementations.
