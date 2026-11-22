# Contributing to 4rmory

1. Add an entry: `4rmory add` (or edit `catalog/armory.tsv` — tab-separated:
   `id · category · kind · name · description · url`).
2. Write the description as **one plain sentence** about what it helps with. No hype.
3. Scan it: `4rmory audit <id>`. Entries rated `high risk` are not accepted.
4. Regenerate the list: `./4rmory export > CATALOG.md`.
5. Run `bash -n 4rmory lib/*.sh` and open a pull request.

Only list repositories that are maintained, public and clearly licensed. Code style: Bash 3.2
compatible, functions prefixed `ar_`, one concern per `lib/*.sh` file.
