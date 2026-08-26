# Repository structure design — dev-research

**Date:** 2026-08-25
**Status:** design approved in conversation; adversarially reviewed (facts, consistency, implementability) and corrected; awaiting owner review of this document
**Scope:** how this repository is laid out, the conventions for research documents and prototypes, how the site is built and published, and how the existing guide migrates in.

## 1. Purpose and decisions

This repository is a personal research monorepo for development concepts and technology. It holds two kinds of things:

1. **Living guides** — one canonical document per question, revised in place as the topic evolves. History lives in git, not in filenames or dated copies.
2. **Full prototypes** — runnable projects that the research leads to, in whatever language fits (C#, TypeScript, Python are all expected).

The guides are published as a static site on GitHub Pages so they can be read and shared without a checkout.

Decisions made during brainstorming, in the order they were taken:

| Question | Decision | Rejected alternatives |
|---|---|---|
| What lives here? | Research **and** full prototypes (monorepo) | docs only; docs + small spikes |
| How do documents evolve? | Living documents, revised in place | dated snapshots; both |
| How is it read? | Published static site | GitHub/editor markdown; Obsidian vault |
| Layout | **A:** `docs/` + `prototypes/` with mirrored topic slugs | B: topic-first co-location (`topics/<t>/{docs,prototypes}`) — fights every site generator's single-docs-root assumption; C: docs-only repo with prototypes as sibling repos — not a monorepo |
| Site generator | **MkDocs Material** | Astro Starlight — wants `src/content/docs/`, burying research three levels deep; Docusaurus — heavier for the same result |
| Repository visibility | **Public** | Private + GitHub Pages — needs GitHub Pro, and the site is public anyway while every link from it back to the repository (prototypes, edit buttons) would be dead for readers; Private + Cloudflare/Vercel/Netlify hosting — replaces the whole deploy design for no gain once the site is public regardless |

The working folder is currently named `ai-development`, but that is the *first topic*, not the repository. Recommended repository name: `dev-research`. Renaming the local folder is the owner's call and should happen outside an active Claude Code session. Nothing in this design depends on the folder name.

## 2. Repository layout

```
dev-research/
├── README.md                     purpose, layout, how to add a topic / guide / prototype, how to run the site
├── mkdocs.yml                    MkDocs Material configuration, including the nav (section 5)
├── requirements.txt              mkdocs-material, mkdocs-git-revision-date-localized-plugin
├── .gitignore                    junk and secrets for Node, Python, .NET, and the MkDocs output (section 4)
├── .github/
│   └── workflows/
│       └── docs.yml              unit tests + strict build on pull requests, pushes to main, and manual runs; deploy on pushes to main and manual runs (section 5)
├── hooks/
│   └── github_parity.py          build hook: fails the strict build on GitHub-only markdown that would render wrong (2026-08-26-github-parity-hook-design.md)
├── tests/
│   └── test_github_parity.py     unit tests for the hook, run in CI before the build
├── docs/                         site source — one folder per topic
│   ├── index.md                  site landing page: what this is, list of topics
│   ├── ai-development/
│   │   ├── index.md              topic landing page: scope, status, guides, related prototypes
│   │   └── loops-and-graphs.md   moved from the repo root (section 6)
│   └── superpowers/
│       └── specs/                design documents such as this one; excluded from the site
└── prototypes/                   runnable projects — one folder per topic, mirroring docs/
    ├── README.md                 the prototype convention, in a few lines
    └── ai-development/           created with the first prototype; each prototype is <topic>/<name>/
```

Rules that follow from the layout:

- A topic uses the **same slug** under `docs/` and `prototypes/` (`ai-development` in both). That is the only link between the two trees.
- `docs/` contains only what the site should publish, plus `superpowers/`, which `mkdocs.yml` excludes.
- Nothing outside `docs/` is copied into the built site. Links from a guide to a prototype are therefore full GitHub URLs (section 3).
- Every page under `docs/` (except `superpowers/`) is listed in the `nav:` block of `mkdocs.yml`. Adding a guide means adding a file **and** a nav line; the strict build fails if the line is forgotten (section 5).

## 3. Document conventions

**Topic = folder, guide = file.** A guide answers one question. A topic folder groups guides and has an `index.md` landing page. Split a guide only when it stops fitting one question, never on line count alone.

**Topic `index.md` contains**, in this order: one-paragraph scope; a status line; a list of guides, each with its `description` sentence repeated by hand; a list of related prototypes with GitHub links (or "none yet").

**Frontmatter on every guide:**

```yaml
---
title: <same text as the guide's H1>
description: <one sentence>
status: needs-review      # optional — draft | needs-review. Omit when the guide is current.
tags: [ai, agents, orchestration]
---
```

- `title` is the page title in the nav and browser tab. The document keeps its own `# H1`, matching `title`.
- `description` is one sentence. Material writes it into the page's `<meta name="description">`; nothing else consumes it automatically. The topic `index.md` repeats it by hand — keep the two identical.
- `status` is the **manual** staleness signal and is deliberately optional: absent means *current*. `draft` = not yet trustworthy; `needs-review` = known or suspected to have drifted. The key is Material's built-in page-status feature, so a guide with a status gets an icon next to its nav entry with the tooltip configured under `extra.status` in `mkdocs.yml` (section 5). Because current guides carry no key, the nav shows icons only where something needs attention.
  A guide may additionally restate its status in the body as `**Status:** current as of <month year>.` (the existing guide does). That line is the human-readable form of the same fact and is changed together with the frontmatter.
- `tags` is free-form and informational. No tags plugin is configured at this stage.
- The **automatic** staleness signal is the `git-revision-date-localized` plugin, which prints "Last update" from git history on every page. No `updated:` field exists, so there is nothing to forget.

**Landing pages** (`docs/index.md` and each topic `index.md`) carry only `title`; `description`, `status`, and `tags` are for guides.

**Links:**

- Between documents: relative markdown links, `../other-topic/guide.md#anchor`. `mkdocs build --strict` fails on a broken file link or a broken anchor (including same-page `#anchor` links), so a rename cannot silently orphan a reference.
- Guides must not link into `docs/superpowers/`. MkDocs logs links to excluded files at INFO level, so the strict build does not catch them and they would 404 on the published site.
- To prototypes and anything else outside `docs/`: the full GitHub URL, e.g. `https://github.com/mortenbrudvik/dev-research/tree/main/prototypes/ai-development/<name>`. The GitHub account is `mortenbrudvik`; the repository name is the owner's choice and `dev-research` is the recommendation used throughout this spec.
- Headings produce anchors via the standard MkDocs `toc` slugifier (lowercase, punctuation stripped, whitespace and hyphen runs collapsed to one hyphen). That matches GitHub's anchors for every heading in the existing guide (verified for every heading), but diverges for headings containing ` - `, `&`, or double spaces, which GitHub does not collapse. The strict build catches any mismatch in in-document links.

**References is the last section of every guide.** A provenance footer, where one exists, follows it (for example "*Compiled from a multi-agent research sweep … on 2026-08-24.*").

## 4. Prototype conventions

- Path: `prototypes/<topic>/<name>/`. `<topic>` mirrors the docs slug; `<name>` is a short kebab-case description of what the prototype demonstrates (e.g. `langgraph-writer-critic`).
- **Self-contained.** Each prototype has its own `README.md` (what it demonstrates, how to run it, a link to the guide section it illustrates), its own tooling and lockfile, and its own language. Mixed stacks side by side are expected.
- **No root-level build or workspace.** No root `package.json`, `.sln`, or `pyproject.toml`. A pnpm workspace or a solution file is added only when several same-stack prototypes make it worth it.
- The root `.gitignore` covers the common artifacts and secrets for all three stacks and the site output:

  ```
  # Node
  node_modules/
  dist/
  .next/
  # Python
  .venv/
  __pycache__/
  *.pyc
  # .NET
  bin/
  obj/
  .vs/
  # Secrets
  .env
  .env.*
  !.env.example
  # MkDocs
  /site/
  # Editors / OS
  .idea/
  .DS_Store
  Thumbs.db
  ```

  The root rules are unanchored except `/site/`, which is pinned to the repository root because MkDocs always writes there and a prototype may legitimately have its own `site/`; `bin/` and `dist/` match at any depth. A prototype that needs one of those directories tracked (a Node CLI with `bin/cli.js`, a deliberately committed `dist/` demo) adds its own `.gitignore` containing e.g. `!bin/`, which re-includes it. The same nested file is where a prototype ignores anything unusual it produces.
- `prototypes/README.md` states this convention so the folder exists in git before the first prototype does. `prototypes/ai-development/` is created together with the first prototype, not before.

## 5. Site build and deploy

### `mkdocs.yml`

```yaml
site_name: Dev Research
site_description: Living guides on development concepts and technology, and the prototypes they lead to.
site_url: https://mortenbrudvik.github.io/dev-research/
repo_url: https://github.com/mortenbrudvik/dev-research
edit_uri: edit/main/docs/

docs_dir: docs
exclude_docs: |
  superpowers/

nav:
  - index.md
  - AI development:
      - ai-development/index.md
      - ai-development/loops-and-graphs.md

hooks:
  - hooks/github_parity.py   # fails the strict build on GitHub-only markdown that would render wrong

validation:
  omitted_files: warn
  absolute_links: warn
  unrecognized_links: warn
  anchors: warn

theme:
  name: material
  features:
    - navigation.indexes       # a topic's index.md is the section's landing page
    - navigation.sections
    - navigation.top
    - toc.follow
    - search.suggest
    - search.highlight
    - content.code.copy
    - content.action.edit      # "edit this page" link to GitHub, built from edit_uri
  palette:
    - scheme: default
      toggle: { icon: material/brightness-7, name: Switch to dark mode }
    - scheme: slate
      toggle: { icon: material/brightness-4, name: Switch to light mode }

extra:
  status:
    draft: Draft — not yet trustworthy
    needs-review: Needs review — known or suspected to have drifted

markdown_extensions:
  - admonition
  - attr_list
  - footnotes
  - tables
  - toc:
      permalink: true
  - pymdownx.details
  - pymdownx.highlight
  - pymdownx.inlinehilite
  - pymdownx.magiclink          # bare URLs become links, as on GitHub
  - pymdownx.tasklist:          # - [ ] task lists, as on GitHub
      custom_checkbox: true
  - pymdownx.tilde              # ~~strikethrough~~, as on GitHub
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.tabbed:
      alternate_style: true

plugins:
  - search
  - git-revision-date-localized:
      enabled: !ENV [CI, false]   # dates come from git history; only meaningful in CI, where files are committed
      type: date
```

Notes on the choices:

- **The nav is explicit.** MkDocs' auto-generated nav titles a section from its folder name (`ai-development` → "Ai development") and offers no way to fix that from frontmatter, so the four-line `nav:` block is the cheaper option. Adding a guide means adding a file and a nav line; `omitted_files: warn` under `--strict` fails the build if the line is forgotten. Nav entries without a label (`- index.md`) take the page's `title`.
- **`exclude_docs`** keeps `docs/superpowers/` out of the build so design specs are versioned but not published.
- **`validation`** raises link and anchor problems as warnings, which `--strict` turns into failures.
- **`hooks/github_parity.py`** (design: `2026-08-26-github-parity-hook-design.md`) runs inside every build and fails `--strict` when a URL is not a link in the rendered page or the source uses GitHub-only syntax that Python-Markdown degrades silently. Its stdlib unit tests under `tests/` run in CI before the build.
- **`pymdownx.magiclink`** autolinks bare URLs. Python-Markdown does not do this by itself, unlike GitHub, and the guides' References sections are written GitHub-style; without it every reference rendered as plain text (found after the first publish, 2026-08-26).
- **`content.action.edit`** is required for Material to render the "edit this page" button that `edit_uri` points at; without it `edit_uri` is inert.
- **`extra.status`** provides the tooltips for the optional `status` frontmatter (section 3). Material renders its default status icon for these values; custom icons would need an `extra.css` and are out of scope.
- **`git-revision-date-localized` is enabled only when `CI` is set** (GitHub Actions sets `CI=true`). Locally, uncommitted files have no history and the plugin would stamp them with today's date — a misleading "Last update" — and with the plugin's default parallel processing that warning is not counted by `--strict`, so nothing would flag it. In CI every file is committed. Local builds therefore show no "Last update" line; that is expected.
- `site_url` and `repo_url` assume the repository name `dev-research` under `mortenbrudvik`; change both lines if the name differs.

### `requirements.txt`

```
mkdocs-material
mkdocs-git-revision-date-localized-plugin
```

Unpinned on purpose: this is a personal docs site, and Material's release cadence is fast; pin only if a release ever breaks the build. (Material itself pins `mkdocs<2`, so the MkDocs 2.0 line cannot be pulled in by accident.)

### Local preview

```
python -m venv .venv
.venv\Scripts\activate          # PowerShell / cmd
pip install -r requirements.txt
mkdocs serve                    # http://127.0.0.1:8000, live reload
mkdocs build --strict           # what CI runs; must pass before pushing
```

Python 3.13 is installed on the development machine and is the version CI uses too; `.venv/` is gitignored.

### `.github/workflows/docs.yml`

```yaml
name: docs

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0            # the date plugin reads git history
      - uses: actions/setup-python@v7
        with:
          python-version: "3.13"
          cache: pip
      - run: pip install -r requirements.txt
      - run: python -m unittest discover -s tests -v
      - run: mkdocs build --strict
      - uses: actions/upload-pages-artifact@v5
        with:
          path: site

  deploy:
    needs: build
    if: github.event_name != 'pull_request'   # pushes to main and manual runs deploy; PRs only build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v5
```

- Action majors are the current ones as of 2026-08-25 (`checkout` v7.0.1, `setup-python` v7.0.0, `upload-pages-artifact` v5.0.0, `deploy-pages` v5.0.0); all run on Node 24, which GitHub's runners default to since June 2026.
- This is the artifact-based Pages flow: no `gh-pages` branch, nothing built is ever committed.
- Pull requests build strictly and stop. Pushes to `main` and manual `workflow_dispatch` runs build and deploy.

### One-time manual steps (owner)

The folder is already `git init`-ed on branch `master` with no commits.

1. `git branch -m main` — the workflow listens to `main`.
2. Review the working tree and commit.
3. Create the GitHub repository and add it as `origin`, without pushing yet: `gh repo create mortenbrudvik/dev-research --public --source . --remote origin` (or via the web UI, then `git remote add origin …`). The repository must be public (section 1).
4. In the repository: **Settings → Pages → Build and deployment → Source: GitHub Actions.** Do this before the first push; if the push lands first, the deploy job fails once — set the source and re-run the workflow from the Actions tab, which deploys because manual runs deploy.
5. `git push -u origin main`. The push runs the `docs` workflow and publishes the site at `site_url`.

## 6. Migration of existing content

1. Move `ai-development-loops-and-graphs.md` → `docs/ai-development/loops-and-graphs.md` (plain move; the file is untracked). Prepend exactly this frontmatter — no `status` key, because the guide is current:

   ```yaml
   ---
   title: AI Development with Loops and Graphs
   description: A practical guide to control flow in agentic AI systems — how the loop and the graph became the two core primitives of AI development, when to use each, and how to build, secure, and operate them.
   tags: [ai, agents, orchestration]
   ---
   ```

   The `description` is the guide's italic subtitle verbatim, without the surrounding asterisks. The body — the `# H1`, the italic subtitle, the `**Status:** current as of August 2026.` line, the in-document table of contents, and the provenance footer after References — is unchanged.
2. Create `docs/index.md` with frontmatter `title: Home`: two paragraphs on what the site is, then the topic list linking to `ai-development/index.md`.
3. Create `docs/ai-development/index.md` with frontmatter `title: AI development`, following the topic-landing structure in section 3: scope paragraph; status line; the one guide with its `description` sentence repeated; "none yet" for prototypes.
4. Create the root `README.md`: purpose; the layout tree from section 2; how to add a topic, a guide (file + nav line), and a prototype; local preview commands; how deployment works; the one-time manual steps from section 5 in the same order.
5. Create `prototypes/README.md`, `.gitignore`, `mkdocs.yml` (including the nav block for the three pages), `requirements.txt`, `.github/workflows/docs.yml` exactly as specified above.
6. This spec stays at `docs/superpowers/specs/2026-08-25-repo-structure-design.md`.

Nothing is committed by the assistant; the owner reviews the working tree and commits.

## 7. Verification

- Local: `python -m unittest discover -s tests -v` passes (the GitHub-parity hook's unit tests).
- Local: create `.venv`, install requirements, run `mkdocs build --strict` with `CI` unset. Pass criterion: exit code 0 and no `WARNING -` log lines. Material prints a boxed, multi-line notice about MkDocs 2.0 on every build; it is informational and does not affect the result. The guide's in-document table-of-contents links are covered by this build (`validation.anchors: warn` under `--strict`).
- Local: `mkdocs serve`, open the site, and confirm: the sidebar section reads "AI development" and links to the topic landing page; the guide's fenced code blocks (text, python, typescript), its tables (sections 2.2, 4.3, 6), and its table-of-contents links render and navigate. Temporarily set `status: needs-review` on the guide and confirm the nav shows a status icon whose tooltip is the `extra.status` text; revert.
- After the owner's first push: the `docs` workflow is green and the site is live at `site_url`, showing a "Last update" date on the guide.

## 8. Out of scope (deliberately not built now)

- Tags index page / tags plugin — `tags` frontmatter is recorded, nothing consumes it yet.
- `awesome-pages`, `mkdocs-monorepo-plugin`, or any nav-generation plugin — the explicit `nav:` block is the mechanism.
- Custom status icons (`extra.css`) — the default Material icon plus the tooltip is enough.
- Root-level workspace, solution file, or shared tooling for prototypes.
- Blog, journal, or dated research logs — the "living documents" decision excludes them.
- Obsidian wikilinks or frontmatter aliases.
- Custom theme overrides, analytics, comments, versioned docs (`mike`), social cards.
- Importing the raw research notes that produced the first guide; only the distilled guide is published.

Each of these can be added later without changing anything decided here.
