# Contributing to 4rmory

## Add a skill or tool

1. Add it: `4rmory add` (or edit `catalog/armory.tsv`, tab-separated:
   `id · category · kind · name · description · url`). `add` scans the repository before saving it.
2. Describe it in **one plain sentence** about what it helps with. Start with a capital letter. No hype.
3. Check your rows before pushing: `./4rmory audit --changed origin/main`.
4. Regenerate the readable list: `./4rmory export > CATALOG.md`.
5. Open a pull request. The **Scan new catalog entries** check scans every row you added or changed with
   NVIDIA SkillSpector and Cisco Skill Scanner. It fails on a malformed row or a **High risk** verdict;
   the reports are attached to the run. *Needs review* passes but a maintainer reads the report.

Maintainers: make this check required in branch protection so nothing unscanned can be merged.

Only list repositories that are public, maintained and clearly licensed.

## Maintainers

```bash
4rmory maintainer on   # add/edit/remove change the shared catalog
4rmory add ...
4rmory publish         # regenerates CATALOG.md, commits and pushes
```

Everyone receives the change with `4rmory update`.

## Code

- Bash 3.2 compatible (macOS default). No new required dependencies.
- Functions are prefixed `ar_`; one concern per `lib/*.sh` file.
- User-facing text starts with a capital letter; prompts accept `Exit`.
- Check before a PR: `bash -n 4rmory lib/*.sh` and run the menu once (`4rmory`).
