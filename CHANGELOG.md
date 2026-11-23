# Changelog

## Unreleased

- **Security sweep:** every bundled skill and every catalog skill/collection was scanned with NVIDIA
  SkillSpector and Cisco Skill Scanner, and each High-risk or flagged result was reviewed by hand.
  - **Removed** bundled `x-twitter` (installs an unverified npm package and asks for Twitter credentials
    while the bundled code is a mock), `glitchward-shield` (sends every prompt and external content to a
    third-party API) and `minimax-usage` (says it checks quota but makes a billable API call).
  - **Fixed** HyperFrames: the link pointed to an unofficial README-only repo; it now points to
    [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes) and is listed as a skill.
  - All other catalog entries were kept: their flags were false alarms (security guides quoting attack
    text, local FFmpeg/Node child processes, API keys sent only to the vendor's own API).
- **Added 23 entries.** Video and motion: yt-dlp, FFmpeg Skill, FFmpeg Usage Skill, Ghost Editor,
  Claude Shorts, REA Video, Awesome Claude Video Skills, Three.js Skills, iArt Motion Skills, Motion
  Graphics (Barty-Bart), OneTake, Collage B-Roll, Pulupulu Motion, MotionClone. Security: Kuron Security,
  ARTEX, Claude-BugHunter, REA. Other: Paperclip, Dokploy, Meetily, rust-anything, Kiri.
  Scan notes are in each description where a scanner flagged something.
- **Added** a Tutorials section to the README.
- **Added** [Terminal CLI Craft](skills/terminal-cli-craft) to Engineering: a general guide for building simple, polished and safe CLIs.
- **Added** [AI MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) to Essentials (scan: needs review).
- **Fixed** Cisco scans of repos that hold many skills (uses `scan-all --recursive`; before, they returned nothing).

## 1.1.0 · 2026-11-23

- **Update brings new skills:** `4rmory update` pulls the shared catalog and lists what's new;
  the menu shows **★ New skills are available!** when updates wait.
- **Personal list:** your add/edit/remove are saved locally and survive updates; removing a
  shared entry hides it (`4rmory unhide`).
- **Maintainer mode:** `4rmory maintainer on` + `4rmory publish` shares catalog changes with everyone.
- **Friendlier menu:** grouped sections, round number badges (Nerd Font; plain fallback,
  `ARMORY_BADGES`), pick results by number then Install / Scan / Edit / Remove.
- **Never kicked out:** empty Enter does nothing; **Exit** replaces Quit; type `Exit` at any prompt to leave.
- **Capitalised labels** everywhere.
- **Fairer scans:** each scanner's own verdict is used; *High risk* only when both agree.
  Scan logs moved to `~/.local/share/4rmory/audit.tsv`.
- **Help:** README Help section and a Getting Started block in `4rmory help`.

## 1.0.0 · 2026-11-22

- First release: Bash CLI to search, install, add/edit/remove and audit agent skills.
- Catalog of 183 entries in 17 categories, imported from the curated directory.
- NVIDIA SkillSpector + Cisco Skill Scanner integration; figlet banner; MIT licence.
