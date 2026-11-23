<div align="center">

<img src="assets/logo.svg" width="120" alt="4rmory logo">

<img src="assets/banner.svg" width="100%" alt="4rmory terminal banner">

### The armory of AI agent skills

**Search, install and safety-scan the best skills and tools for Claude Code, Codex, OpenCode and other agents — from one small Bash command.**

[![Bash](https://img.shields.io/badge/bash-3.2%2B-4EAA25?logo=gnubash&logoColor=white)](#requirements)
[![Version](https://img.shields.io/badge/version-1.1.0-2aa7ff)](CHANGELOG.md)
[![Catalog](https://img.shields.io/badge/catalog-208%20entries-2aa7ff)](CATALOG.md)
[![Scanned](https://img.shields.io/badge/scanned%20with-SkillSpector%20%2B%20Cisco-76B900)](#safety-first)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

[Quick start](#quick-start) · [Commands](#commands) · [Categories](#categories) · [Safety](#safety-first) · [Contributing](#add-your-own) · [Help](#help) · [Security](SECURITY.md)

</div>

---

## Why 4rmory?

There are thousands of agent skills on GitHub. Some are great, many are noise, and a few are dangerous.
4rmory is a hand-picked catalog sorted into clear categories, plus a CLI that:

- 🔎 **finds** the right skill in seconds (`4rmory search video script`)
- 📦 **installs** it into your agent's skills folder with one command
- 🛡️ **scans it first** with NVIDIA SkillSpector, Cisco Skill Scanner and a built-in check — high-risk installs are blocked
- ✏️ **lets you curate** your own list: add, edit and remove entries
- 🔄 **keeps you current**: `4rmory update` pulls newly added skills and tells you what's new

## Quick start

```bash
git clone https://github.com/Z1esco/4rmory.git
cd 4rmory && ./install.sh
4rmory setup
```

`setup` asks which agent you use and which areas you work in, then scans and installs the matching skills.
Run `4rmory` with no arguments any time for a simple menu:

```text
  FIND
  ①  Search                     Find skills and tools by keyword
  ②  Browse Categories          Look through one area at a time
  INSTALL
  ③  Guided Setup               Pick your agent and areas, install all
  ④  My Installed Skills        See what you have
  ⑤  Update                     ★ New skills are available!
  YOUR LIST
  ⑥  Add A Skill Or Tool        Save a new one to the list
  ⑦  Edit Or Remove             Change an entry
  SAFETY & HELP
  ⑧  Scan For Malware           Check a skill or a folder
  ⑨  Doctor                     Check your setup
  ⑩  Help                       All commands

  ⓪  Exit

  Type a number and press Enter · Type Exit anytime to leave
```

Type a number and press Enter. Empty Enter never kicks you out; `0` or `Exit` (at any prompt) leaves.

### Requirements

| Needed | Optional (better experience) |
|---|---|
| `bash` 3.2+, `git`, `awk` | `python3` (scanner reports), `fzf` (arrow-key menus), `figlet` (live banner) |
| Linux or macOS | A [Nerd Font](https://www.nerdfonts.com) (round number badges) |
| | [`skillspector`](https://github.com/NVIDIA/SkillSpector) and [`skill-scanner`](https://github.com/cisco-ai-defense/skill-scanner) (deep security scans) |

Install the scanners with [`uv`](https://docs.astral.sh/uv/) (fast; `pipx install` also works but can be slow):

```bash
uv tool install git+https://github.com/NVIDIA/skillspector.git
uv tool install cisco-ai-skill-scanner
4rmory doctor
```

## Commands

<div align="center">

| Find | Install | Manage | Safety |
|:---|:---|:---|:---|
| `search <words>` | `setup` | `add` | `audit <id>` |
| `list [category]` | `install <id>` | `edit <id>` | `audit --installed` |
| `categories` | `uninstall <id>` | `remove <id>` | `doctor` |
| `info <id>` | `installed` · `update` | `export` · `unhide` | `maintainer` · `publish` |

</div>

```bash
4rmory search humanizer                 # search everything
4rmory search marketing -k skill        # only installable skills
4rmory list design                      # one category
4rmory info superpowers                 # details, install and audit status
4rmory install superpowers --agent claude
4rmory audit --installed                # re-scan what you have
```

Install targets: `claude` → `~/.claude/skills`, `codex` → `~/.codex/skills`,
`opencode` → `~/.config/opencode/skills`, `agents` → `~/.agents/skills`.
Downloads live in `~/.local/share/4rmory` and skills are linked, never copied over your own files.

**Kinds:** 🟢 `skill` (installs into your agent) · 🔵 `tool` (an app or library — follow its README) · 🟣 `mcp` · 🟡 `collection` (a list to discover more).

## Categories

<div align="center">

| | Category | What's inside |
|:-:|:--|:--|
| ⭐ | `essentials` | Start here: must-have agent skills |
| 🎨 | `design` | UI/UX, web design and anti-slop |
| 🧠 | `engineering` | Code understanding and software engineering |
| ✍️ | `copywriting` | Copywriting, marketing and brand voice |
| 📱 | `social` | Captions and social media |
| ▶️ | `youtube` | YouTube and creator workflows |
| 🎬 | `motion` | Motion design, animation and game visuals |
| 🖼️ | `image` | Image generation and visual AI |
| 🎧 | `audio` | Audio, voice and speech-to-text |
| 📖 | `fiction` | Novels, fiction and screenwriting |
| 🪶 | `editing` | Humanizer, editing and natural writing |
| 🔬 | `research` | Research, OSINT and knowledge work |
| 🛡️ | `security` | Cybersecurity and secure AI agents |
| ⚙️ | `automation` | Automation, agents and MCP |
| 📄 | `docs` | Documents, reports and knowledge bases |
| 📊 | `data` | Data, analytics and machine learning |
| 🚀 | `product` | Product, SaaS and growth |

</div>

The full, readable list is in [CATALOG.md](CATALOG.md) (generated with `4rmory export`).

### Tutorials

Guides that aren't git repositories, so they can't be installed or scanned. External and unreviewed: read before you follow them.

| Tutorial | What it covers |
|---|---|
| [Claude educational animation from zero](https://app.notion.com/p/CLAUDE-TUTORIAL-SKILL-41b220b82d6980d2b579c24d8458d17c?source=copy_link) (Notion, Indonesian) | Video tutorial and skill links for making educational animations with Claude. |

For AI video editing, start with [HyperFrames](https://github.com/heygen-com/hyperframes), [OneTake](https://github.com/feitangyuan/onetake) and [Collage B-Roll](https://github.com/pyang5166/gbro-collage-broll) (`4rmory info hyperframes`).

## Safety first

Every skill is scanned **before** it joins a list and again **before** it is linked into your agent:

| When | What is scanned |
|---|---|
| `4rmory add` | The new repository, before the entry is saved |
| `4rmory edit <id> url …` | The new link, before it replaces the old one |
| `4rmory publish` | Every new or changed shared-catalog row |
| Pull request to this repo | Every added or changed row, by GitHub Actions ([scan-catalog.yml](.github/workflows/scan-catalog.yml)) |
| `4rmory install` | The skill, before it is linked into your agent |

The scanners:

1. **[NVIDIA SkillSpector](https://github.com/NVIDIA/SkillSpector)** — malicious patterns, prompt injection, data exfiltration, supply-chain risk.
2. **[Cisco Skill Scanner](https://github.com/cisco-ai-defense/skill-scanner)** — static, behavioural and YARA analysis.
3. **Built-in check** — fast grep for pipe-to-shell, reverse shells, credential paths, webhooks and miners.

| Verdict | Meaning | What happens |
|---|---|---|
| ✅ **Clean** | No scanner found a problem | Added / installed |
| ⚠️ **Needs review** | One scanner flagged something | Asks *"Save anyway?"* / *"Install anyway?"* (`-y` answers yes) |
| ⛔ **High risk** | Both scanners agree it looks dangerous | Blocked (only `--force` after reading the report); a pull request check fails |

The built-in check is advisory and only decides on its own when no scanner is installed.
Each scanner gets `ARMORY_SCAN_TIMEOUT` seconds (default 900); a scanner that times out counts as *Needs review*.
Results are logged in `~/.local/share/4rmory/audit.tsv`, with full reports in `reports/`.
Scanners find known risk patterns; they don't prove a skill is safe. Read what you install.

## Get new skills

New skills and tools are added to the shared catalog over time. To get them:

```bash
4rmory update        # pulls the newest catalog and lists what is new
```

The menu checks GitHub every few hours and shows **★ New skills are available!** next to *Update*.

## Add your own

```bash
4rmory add                                    # guided; the repo is scanned before it is saved
4rmory add --name "My Skill" --url https://github.com/me/my-skill \
           -c engineering -k skill -d "Plain sentence: what it helps with."
4rmory edit my-skill description "Better wording"
4rmory edit my-skill url https://github.com/me/new-home   # the new link is scanned first
4rmory remove my-skill
4rmory audit my-skill                         # scan again any time
```

If a scan says **High risk**, the entry is not saved. Read the report it prints; only if you trust
the code, run the same command again with `--force`.

Your additions and edits go to **your personal list** (`~/.local/share/4rmory/my-catalog.tsv`), so they
survive updates. Removing a shared entry hides it for you (`4rmory unhide <id>` brings it back).

**Maintainers** share additions with everyone:

```bash
4rmory maintainer on     # add/edit/remove now change the shared catalog
4rmory add ...           # add as usual
4rmory publish           # commit + push; everyone gets it on `4rmory update`
```

The shared catalog is one tab-separated file, [`catalog/armory.tsv`](catalog/armory.tsv):
`id · category · kind · name · description · url`. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Help

<details open>
<summary><b>📥 How do I install 4rmory?</b></summary>

```bash
git clone https://github.com/Z1esco/4rmory.git
cd 4rmory
./install.sh          # adds the 4rmory command to ~/.local/bin
4rmory doctor         # checks git, scanners and optional extras
```

If `4rmory` is "command not found", add `~/.local/bin` to your PATH:
`echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc`
</details>

<details>
<summary><b>🧭 How do I set it up for my agent?</b></summary>

Run `4rmory setup` (or `4rmory` → **3 Guided Setup**):

1. Pick your agent: Claude, Codex, OpenCode or Agents.
2. Pick the areas you work in, one per number. Press **Enter** when done.
3. Confirm. Each skill is scanned, then linked into your agent's skills folder.
4. Restart your agent so it loads the new skills.
</details>

<details>
<summary><b>🔍 How do I find and install one skill?</b></summary>

- In the menu: **1 Search** → type words → type the result's number → **Install**.
- From the shell: `4rmory search <words>`, then `4rmory install <id> --agent claude`.
- Not sure of the id? `4rmory info <id>` shows it, or browse with `4rmory list <category>`.
</details>

<details>
<summary><b>🔄 How do I update?</b></summary>

`4rmory update` (menu **5**) gets the newest catalog, lists the new skills, and updates the
skills you installed. When the menu shows **★ New skills are available!**, there is something new.
</details>

<details>
<summary><b>➕ How do I add, edit or remove a skill?</b></summary>

- Add: `4rmory add` (it asks for name, link, category, kind and a one-line description).
- Edit: `4rmory edit <id>` · Remove: `4rmory remove <id>` · Undo a remove: `4rmory unhide <id>`.
- Your changes stay on your machine and survive updates. To share with everyone, open a pull request
  (see [CONTRIBUTING.md](CONTRIBUTING.md)), or as a maintainer run `4rmory publish`.
</details>

<details>
<summary><b>🛡️ A scan says "Needs review" or "High risk". What now?</b></summary>

- **Needs review:** one scanner flagged something. Open the report path it prints. Often it is
  a security guide quoting attack text. You choose whether to install.
- **High risk:** both scanners agree. The install is blocked. Only use `--force` if you have read
  the code and trust it.
</details>

<details>
<summary><b>🗑️ How do I uninstall?</b></summary>

- One skill: `4rmory uninstall <id>` (removes its links and downloaded copy).
- 4rmory itself: `rm ~/.local/bin/4rmory`, delete the cloned folder, and optionally `~/.local/share/4rmory`.
</details>

<details>
<summary><b>⌨️ Menu tips</b></summary>

Type a number and press Enter. An empty Enter does nothing, so you never get kicked out.
With `fzf` installed, use the arrow keys and press Esc to go back.
`0` or typing `Exit` at any prompt leaves 4rmory. Install `fzf` for arrow-key menus. `NO_COLOR=1 4rmory` turns colours off.
Numbers show as round badges when a [Nerd Font](https://www.nerdfonts.com) is installed; force a style with `ARMORY_BADGES=round` or `ARMORY_BADGES=plain`.
Still stuck? Run `4rmory help`, or open an [issue](https://github.com/Z1esco/4rmory/issues).
</details>

## Project layout

```
4rmory            entry point (loads lib/*)
install.sh        links the 4rmory command into ~/.local/bin
lib/core.sh       paths, agents, validation
lib/theme.sh      colours (respects NO_COLOR)
lib/ui.sh         banner, prompts, menus
lib/catalog.sh    search, list, add, edit, remove, export
lib/install.sh    clone, link, uninstall, update, setup
lib/audit.sh      SkillSpector + Cisco + built-in scans
catalog/          armory.tsv (the shared list)
assets/           logo, banner (SVG) and the fallback text banner
skills/           a few bundled example skills
tools/            import_md.py: rebuild the catalog from a Markdown directory

Your data (never in the repo): ~/.local/share/4rmory/
  repos/  installed.tsv  my-catalog.tsv  hidden.txt  audit.tsv  reports/
```

<div align="center">

---

Made for people who'd rather build than browse. · [Changelog](CHANGELOG.md) · [Security](SECURITY.md) · [MIT License](LICENSE)

</div>
