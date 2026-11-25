<div align="center">

<img src="assets/logo.svg" width="80" alt="4rmory logo">

# Security Policy

</div>

## How 4rmory keeps you safe

| Protection | What it means |
|---|---|
| **Scan before install** | Every install is scanned with NVIDIA SkillSpector, Cisco Skill Scanner (when installed) and a built-in pattern check before anything is linked into your agent. |
| **Scan before listing** | `add`, a link change with `edit`, and `publish` scan the repository before it is saved. Pull requests that touch the catalog are scanned by GitHub Actions using the scanner code from the base branch, so a pull request cannot switch off its own scan. |
| **Two-scanner rule** | *High risk* (install blocked) only when both scanners agree. One scanner alone gives *Needs review* and you decide. `--force` is the only way past a block. |
| **Never runs downloaded code** | 4rmory only runs `git clone --depth 1` and links folders that contain a `SKILL.md`. No install scripts, no pipe-to-shell. |
| **Never overwrites your files** | Links are only created where nothing exists, or where 4rmory made the link itself. Uninstall removes only what 4rmory created. |
| **Strict input checks** | Ids are `a-z 0-9 -`. URLs must be `https://` GitHub, GitLab or Codeberg repositories with no shell characters. Catalog fields are stripped of tabs and newlines. |
| **No telemetry, no AI upload** | Nothing is sent anywhere except `git` to the repository you install or update from, and (only when you open **Show Details**) a download of that repository's README and pictures from its host. Scanners run with `--no-llm`, so code is never sent to an AI provider. |
| **Safe details view** | README text is stripped of terminal control characters before it is shown; pictures are size-capped and only drawn if they really are PNG, JPEG, GIF or WebP. |
| **Your data stays local** | Installs, your personal list, scan logs and reports live in `~/.local/share/4rmory/`, never in the repository. |
| **No secrets in the repo** | The repository and its full git history were reviewed for keys, tokens, emails and personal paths (2026-11-23): none found. |

## Limits

Scanners find **known** risk patterns. A clean scan does not prove a skill is safe. Before you trust a
skill with your files, shell or accounts, read its `SKILL.md` and any scripts. Reports are saved at
`~/.local/share/4rmory/reports/<id>.txt`.

## Supported versions

| Version | Supported |
|---|---|
| 1.1.x | ✅ |
| 1.0.x | ⚠️ Update with `4rmory update` |

## Reporting a vulnerability

- **In 4rmory itself:** open a [private security advisory](https://github.com/Z1esco/4rmory/security/advisories/new).
  Please don't file public issues for vulnerabilities.
- **A malicious or unsafe catalog entry:** open an issue titled `unsafe: <id>` and attach the scan
  report. Confirmed entries are removed and the fix reaches everyone on `4rmory update`.

We aim to reply within 7 days.
