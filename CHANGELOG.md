# Changelog

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
