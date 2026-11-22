<div align="center">

<img src="assets/logo.svg" width="80" alt="4rmory logo">

# Security Policy

</div>

## What 4rmory does to keep you safe

- **Scan before install.** `4rmory install` downloads a repository, scans it with NVIDIA SkillSpector,
  Cisco Skill Scanner (when installed) and a built-in pattern check, and stops on high-risk findings.
- **No pipe-to-shell.** 4rmory never runs code from a downloaded repository. It only clones with
  `git clone --depth 1` and links folders that contain a `SKILL.md`.
- **Never overwrites your files.** Links are only created where nothing exists, or where 4rmory made the link.
- **Strict input checks.** Ids are `a-z 0-9 -`; URLs must be `https://` GitHub, GitLab or Codeberg
  repositories with no shell characters; catalog fields are stripped of tabs and newlines.
- **No secrets, no telemetry.** 4rmory sends nothing anywhere except `git` to the repository you install.
  Scanners run with `--no-llm` by default, so your code is not sent to an AI provider.

## Limits

Scanners find known risk patterns. A clean scan does not prove a skill is safe. Read a skill's
`SKILL.md` and scripts before you trust it with your files, shell or accounts.

## Supported versions

| Version | Supported |
|---|---|
| 1.x | ✅ |

## Reporting a vulnerability

- **In 4rmory itself:** open a [private security advisory](https://github.com/Z1esco/4rmory/security/advisories/new).
  Please don't file public issues for vulnerabilities.
- **A malicious or unsafe catalog entry:** open an issue titled `unsafe: <id>` with the scan report
  (`~/.local/share/4rmory/reports/<id>.txt`). We remove confirmed entries quickly.

We aim to reply within 7 days.
