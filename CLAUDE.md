# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`dev-research` (github.com/mortenbrudvik/dev-research): a personal research monorepo. Living guides under `docs/` are published with MkDocs Material to https://mortenbrudvik.github.io/dev-research/; runnable prototypes the research leads to live under `prototypes/`. The local folder is still named `ai-development` — that is the first *topic* slug, not the project name.

The design rationale is in `docs/superpowers/specs/2026-08-25-repo-structure-design.md`; read it before changing conventions rather than re-deriving them.

## Commands

```
python -m venv .venv && .venv\Scripts\activate      # Git Bash: source .venv/Scripts/activate
pip install -r requirements.txt
mkdocs serve                                        # http://127.0.0.1:8000, live reload
mkdocs build --strict                               # THE test suite — must exit 0 with no "WARNING -" lines
```

Without activating: `.venv/Scripts/python -m mkdocs build --strict`.

- `--strict` turns broken file links, broken anchors (including same-page `#anchor` links), and pages missing from `nav:` into failures. There is no other test suite.
- Every build prints a boxed "Warning from the Material for MkDocs team" notice about MkDocs 2.0 on stdout. It is informational, not a `WARNING -` log line; ignore it.
- Do not validate `mkdocs.yml` with `yaml.safe_load` — it fails on the `!ENV` and `!!python/name:` tags the file needs. The strict build (or `python -c "from mkdocs.config import load_config; load_config()"`) is the check. Plain `yaml.safe_load` is fine for `.github/workflows/docs.yml` (note PyYAML reads the `on:` key as boolean `True`).
- Local builds show no "Last update" dates. The `git-revision-date-localized` plugin is gated on the `CI` env var being exactly `true` (`enabled: !ENV [CI, false]`); `CI=1` makes MkDocs abort with a type error, and running it locally on uncommitted files would stamp them with today's date.
- `python -m mkdocs --version` prints a `python -m mkdocs, version …` prefix; that is Click echoing the program name, not a version mismatch.

## Structure and its contracts

Two trees, joined only by a shared topic slug:

- `docs/<topic>/` — site source. `index.md` is the topic landing page (scope paragraph, `**Status:**` line, Guides list, Prototypes list or "None yet"); each guide is one file answering one question, with References as its last section.
- `prototypes/<topic>/<name>/` — self-contained runnable projects (own README, own tooling and lockfile, any language). No root-level workspace, `.sln`, or `package.json`; add one only when several same-stack prototypes justify it. `prototypes/<topic>/` is created with the first prototype, not before.
- `docs/superpowers/` — design specs and plans. Versioned but **excluded from the site** (`exclude_docs`). Never link to it from a guide: MkDocs logs links to excluded files at INFO, so the strict build will not catch the resulting 404.

**Nav is explicit.** `mkdocs.yml` lists every page; auto-nav was rejected because it titles the section "Ai development" from the folder name. Adding a guide is therefore three edits, and the strict build fails if the middle one is forgotten:

1. `docs/<topic>/<guide>.md` with frontmatter
2. a line under the topic's section in `nav:`
3. an entry in `docs/<topic>/index.md` repeating the guide's `description` sentence verbatim

A new topic additionally needs a `nav:` section whose first entry is its `index.md` (that is what makes `navigation.indexes` treat it as the section page) and a bullet in `docs/index.md`.

**Frontmatter contract.** Guides carry `title` (identical to the H1), `description` (one sentence; becomes the meta description and is repeated by hand in the topic index), `tags`, and *optionally* `status`. Landing pages carry only `title`.

`status` is Material's built-in page-status key: any value renders an icon next to the nav entry with the tooltip from `extra.status` in `mkdocs.yml`. Only `draft` and `needs-review` are defined; **omit the key when a guide is current** so icons appear only where attention is needed. A guide may also carry a visible `**Status:** current as of <month year>.` line in its body; change it together with the frontmatter.

**Links.** Between docs: relative markdown links (`../other-topic/guide.md#anchor`). To prototypes or anything outside `docs/`: full GitHub URLs (`https://github.com/mortenbrudvik/dev-research/tree/main/prototypes/<topic>/<name>`), because nothing outside `docs/` is copied into the site. MkDocs' slugifier matches GitHub's for plain headings but collapses runs of spaces/hyphens (`A - B` → `a-b`, GitHub gives `a---b`); the strict build catches in-document mismatches.

## CI and publishing

`.github/workflows/docs.yml`: pull requests and pushes to `main` run the strict build; pushes to `main` and manual `workflow_dispatch` runs also deploy (artifact-based Pages flow, no `gh-pages` branch). `fetch-depth: 0` is required so the date plugin can read history. Pages is already configured with source = GitHub Actions; the repository must stay public for Pages to work on this account.

## Git and hygiene

- The owner commits. Leave the working tree for review unless explicitly asked to commit or push.
- `core.autocrlf=true` is set on this machine and the repo has no `.gitattributes`: files are LF in the tree and `git add` prints "LF will be replaced by CRLF" — harmless. On Git Bash, `sed -i` silently rewrites CRLF files as LF; prefer the Edit tool for in-place changes to tracked files.
- `.gitignore` is unanchored except `/site/` (MkDocs output is always at the root; a prototype may have its own `site/`). `bin/`, `dist/`, `.env`, `.env.*` match at any depth; a prototype re-includes what it needs with a nested `.gitignore` (`!bin/`). `.env.example` is the only committed env-template name.
- `git check-ignore` only matches directory-only patterns against paths it knows are directories: pass `site/` with a trailing slash when the directory does not exist yet.
