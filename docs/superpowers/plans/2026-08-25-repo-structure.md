# Repository Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the freshly initialised `C:\code\prototypes\ai-development` repository into the `dev-research` monorepo described in `docs/superpowers/specs/2026-08-25-repo-structure-design.md`: a MkDocs Material site under `docs/`, a `prototypes/` tree, CI that publishes to GitHub Pages, and the existing guide migrated in.

**Architecture:** Two top-level trees — `docs/` (site source, one folder per topic, explicit nav in `mkdocs.yml`) and `prototypes/` (self-contained runnable projects, mirrored topic slugs). The site is built with `mkdocs build --strict`, which is the test suite: broken links, broken anchors, and pages missing from the nav fail the build. Deployment is the artifact-based GitHub Pages flow from a single workflow.

**Tech Stack:** Python 3.13 (installed), MkDocs 1.6 + Material 9.7 + `mkdocs-git-revision-date-localized-plugin` (installed into `.venv`), GitHub Actions (`checkout@v7`, `setup-python@v7`, `upload-pages-artifact@v5`, `deploy-pages@v5`), git 2.47, `gh` CLI (already authenticated as `mortenbrudvik`).

**Owner rule — no commits from the assistant.** The repository owner's global instruction is "Never do git commit". This plan therefore has **no commit steps**. Each task leaves the working tree in a state the owner can inspect; Task 10 hands the whole tree over for review and commit. Do not run `git commit`, `git add`, or `git push`.

**Shell note.** Commands are written for Git Bash (the `Bash` tool), run from the repository root `C:\code\prototypes\ai-development`. The venv's interpreter is called explicitly as `.venv/Scripts/python` so no activation is needed. In PowerShell the same path is `.venv\Scripts\python`. A build takes 2–5 seconds.

**Expected-output note.** Every `mkdocs build` prints a boxed, multi-line notice from the Material team about MkDocs 2.0 on stdout. It is informational: it is not a `WARNING -` log line, does not affect `--strict`, and must be ignored when a step says "no warnings".

---

## File map

| Path | Responsibility | Task |
|---|---|---|
| `.gitignore` | Ignore Node/Python/.NET artifacts, secrets, and the MkDocs output | 1 |
| `requirements.txt` | Python packages that build the site | 1 |
| `mkdocs.yml` | Site configuration: nav, theme, extensions, validation, plugins | 2 |
| `docs/ai-development/loops-and-graphs.md` | The existing guide, moved, with frontmatter | 3 |
| `docs/ai-development/index.md` | Topic landing page | 4 |
| `docs/index.md` | Site landing page | 5 |
| `prototypes/README.md` | The prototype convention | 7 |
| `README.md` | Repository overview and how-to | 8 |
| `.github/workflows/docs.yml` | Build on push/PR, deploy on push to `main` and manual runs | 9 |

`docs/superpowers/specs/…` and `docs/superpowers/plans/…` already exist and are excluded from the site by `mkdocs.yml`.

---

### Task 1: Ignore rules and Python toolchain

**Files:**
- Create: `.gitignore`
- Create: `requirements.txt`
- Create (untracked, ignored): `.venv/`

- [ ] **Step 1: Create `.gitignore`**

Create `.gitignore` at the repository root with exactly this content:

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

- [ ] **Step 2: Create `requirements.txt`**

Create `requirements.txt` at the repository root with exactly this content:

```
mkdocs-material
mkdocs-git-revision-date-localized-plugin
```

- [ ] **Step 3: Create the virtual environment and install**

Run:

```bash
python -m venv .venv && .venv/Scripts/python -m pip install -q -r requirements.txt && .venv/Scripts/python -m mkdocs --version
```

Expected: the last line is `python -m mkdocs, version 1.6.x from C:\code\prototypes\ai-development\.venv\Lib\site-packages\mkdocs (Python 3.13)` (Click prints the invoking program name, hence the `python -m` prefix). Any `1.6.*` is fine. If the version starts with `2.`, stop: Material pins `mkdocs<2`, so this means the install did not resolve `mkdocs-material` — re-run the install and read its error.

- [ ] **Step 4: Verify the ignore rules take effect**

Run:

```bash
git check-ignore -v .venv site/ .env && git status --short
```

Expected:

```
.gitignore:6:.venv/	.venv
.gitignore:18:/site/	site/
.gitignore:14:.env	.env
?? .gitignore
?? ai-development-loops-and-graphs.md
?? docs/
?? requirements.txt
```

`.venv/` must not appear in `git status`. (The `.gitignore:N` line numbers are as listed if the file was created exactly as shown. `site/` is passed with a trailing slash because the directory does not exist yet and `git check-ignore` only matches a directory-only pattern against a path it knows is a directory.)

---

### Task 2: Site configuration — the failing build

The nav in `mkdocs.yml` lists three pages that do not exist yet. Under `--strict` that is a failing build; Tasks 3–5 make it pass one page at a time.

**Files:**
- Create: `mkdocs.yml`

- [ ] **Step 1: Create `mkdocs.yml`**

Create `mkdocs.yml` at the repository root with exactly this content:

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

- [ ] **Step 2: Run the strict build and confirm it fails for the right reason**

Run:

```bash
.venv/Scripts/python -m mkdocs build --strict; echo "exit=$?"
```

Expected: three `WARNING -` lines, one per nav entry, each saying the referenced page (`index.md`, `ai-development/index.md`, `ai-development/loops-and-graphs.md`) is included in the `nav` configuration but not found in the documentation files; then `Aborted with 3 warnings in strict mode!` and `exit=1`.

If instead you see an `ERROR` about the configuration (unknown key, bad YAML, unknown plugin), the file was not created as shown or the install in Task 1 is incomplete — fix that before continuing. The nav warnings are the only acceptable failure.

---

### Task 3: Migrate the guide

**Files:**
- Move: `ai-development-loops-and-graphs.md` → `docs/ai-development/loops-and-graphs.md`
- Modify: `docs/ai-development/loops-and-graphs.md` (prepend frontmatter)

- [ ] **Step 1: Move the file**

Run:

```bash
mkdir -p docs/ai-development && mv ai-development-loops-and-graphs.md docs/ai-development/loops-and-graphs.md && head -3 docs/ai-development/loops-and-graphs.md
```

Expected:

```
# AI Development with Loops and Graphs

*A practical guide to control flow in agentic AI systems — how the loop and the graph became the two core primitives of AI development, when to use each, and how to build, secure, and operate them.*
```

- [ ] **Step 2: Prepend the frontmatter**

Using the Edit tool (or an editor), replace the first two lines of `docs/ai-development/loops-and-graphs.md`

```
# AI Development with Loops and Graphs

```

with the frontmatter followed by those same two lines:

```
---
title: AI Development with Loops and Graphs
description: A practical guide to control flow in agentic AI systems — how the loop and the graph became the two core primitives of AI development, when to use each, and how to build, secure, and operate them.
tags: [ai, agents, orchestration]
---

# AI Development with Loops and Graphs

```

There is deliberately **no `status:` key**: the guide is current, and the spec makes `status` optional with absent meaning current. The `description` is the italic subtitle verbatim without its asterisks. Nothing else in the file changes.

- [ ] **Step 3: Verify the file head and that the original path is gone**

Run:

```bash
head -8 docs/ai-development/loops-and-graphs.md; echo "---- old path ----"; test ! -e ai-development-loops-and-graphs.md && echo "old path gone"
```

Expected:

```
---
title: AI Development with Loops and Graphs
description: A practical guide to control flow in agentic AI systems — how the loop and the graph became the two core primitives of AI development, when to use each, and how to build, secure, and operate them.
tags: [ai, agents, orchestration]
---

# AI Development with Loops and Graphs

---- old path ----
old path gone
```

- [ ] **Step 4: Run the strict build — two warnings left**

Run:

```bash
.venv/Scripts/python -m mkdocs build --strict; echo "exit=$?"
```

Expected: two `WARNING -` lines (for `index.md` and `ai-development/index.md` not found), `Aborted with 2 warnings in strict mode!`, `exit=1`. There must be **no** warning about `loops-and-graphs.md` itself — a warning mentioning an anchor or a link inside it means the file was altered beyond the frontmatter.

---

### Task 4: Topic landing page

**Files:**
- Create: `docs/ai-development/index.md`

- [ ] **Step 1: Create the topic landing page**

Create `docs/ai-development/index.md` with exactly this content:

```markdown
---
title: AI development
---

# AI development

Building software with large language models at the centre: the control-flow primitives (agent loops and state graphs), the frameworks that implement them, and what it takes to run them in production — evaluation, cost, human oversight, security, and memory. The scope is the engineering of agentic systems, not model training.

**Status:** one guide, current as of August 2026.

## Guides

- [AI Development with Loops and Graphs](loops-and-graphs.md)

    A practical guide to control flow in agentic AI systems — how the loop and the graph became the two core primitives of AI development, when to use each, and how to build, secure, and operate them.

## Prototypes

None yet.
```

The description paragraph under the guide link is the guide's `description` frontmatter, repeated verbatim as the spec requires (indented four spaces so it renders as a paragraph inside the list item).

- [ ] **Step 2: Run the strict build — one warning left**

Run:

```bash
.venv/Scripts/python -m mkdocs build --strict; echo "exit=$?"
```

Expected: one `WARNING -` line (for `index.md` not found), `Aborted with 1 warnings in strict mode!`, `exit=1`.

---

### Task 5: Site landing page — the build goes green

**Files:**
- Create: `docs/index.md`

- [ ] **Step 1: Create the site landing page**

Create `docs/index.md` with exactly this content:

```markdown
---
title: Home
---

# Dev Research

Living guides on development concepts and technology, and the prototypes they lead to. Each topic holds one canonical guide per question, revised in place as the subject evolves; the git history is the changelog, and every published page shows when it was last updated.

The guides distil research sweeps into something to act on: what a concept is, when to use it, how the tooling compares, and what goes wrong in production. Where a guide leads to runnable code, the prototype lives in the same repository under `prototypes/` and is linked from the topic page.

## Topics

- [AI development](ai-development/index.md) — control flow in agentic AI systems: loops, graphs, frameworks, production, security, memory, and protocols.
```

- [ ] **Step 2: Run the strict build — it passes**

Run:

```bash
.venv/Scripts/python -m mkdocs build --strict; echo "exit=$?"
```

Expected: no `WARNING -` lines (the boxed Material notice is fine), a line `INFO    -  Documentation built in N.NN seconds`, and `exit=0`.

- [ ] **Step 3: Confirm there are zero warning lines, mechanically**

Run:

```bash
.venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c 'WARNING -'
```

Expected: `0`

- [ ] **Step 4: Check the built site's structure**

Run:

```bash
test ! -e site/superpowers && echo "specs excluded"; \
grep -c 'id="12-references"' site/ai-development/loops-and-graphs/index.html; \
grep -c 'id="1-the-central-question-who-holds-the-program-counter"' site/ai-development/loops-and-graphs/index.html; \
grep -c 'name="description" content="A practical guide to control flow' site/ai-development/loops-and-graphs/index.html; \
grep -o 'AI development' site/index.html | head -1; \
grep -c 'Ai development' site/index.html; \
ls site/ai-development/
```

Expected:

```
specs excluded
1
1
1
AI development
0
index.html  loops-and-graphs
```

Meaning: `docs/superpowers/` was excluded; the guide's first and last table-of-contents anchors exist as heading ids; the frontmatter description reached the meta tag; the nav section is labelled "AI development" and the auto-nav spelling "Ai development" appears nowhere; the topic index and the guide were both rendered.

- [ ] **Step 5: Optional visual check**

Run `.venv/Scripts/python -m mkdocs serve` and open http://127.0.0.1:8000. Confirm: the sidebar shows **Home** and a section **AI development** whose label links to the topic page; the guide page shows code blocks with copy buttons, the tables in sections 2.2, 4.3 and 6, and clicking table-of-contents entries jumps to the headings. Stop the server with Ctrl+C. Skip this step if running unattended; Step 4 already verified the same facts mechanically.

---

### Task 6: Verify the page-status feature

This proves the `extra.status` configuration works before any guide relies on it. It temporarily edits the guide and reverts it. On Git Bash, `sed -i` rewrites CRLF files as LF; the guide is LF-only so that is harmless here, but on a CRLF checkout take `tail -n +7 docs/ai-development/loops-and-graphs.md | md5sum` before Step 1 and compare it after Step 3.

**Files:**
- Modify then revert: `docs/ai-development/loops-and-graphs.md`

- [ ] **Step 1: Insert a temporary status**

Run:

```bash
sed -i '3a status: needs-review' docs/ai-development/loops-and-graphs.md && sed -n '1,6p' docs/ai-development/loops-and-graphs.md
```

Expected:

```
---
title: AI Development with Loops and Graphs
description: A practical guide to control flow in agentic AI systems — how the loop and the graph became the two core primitives of AI development, when to use each, and how to build, secure, and operate them.
status: needs-review
tags: [ai, agents, orchestration]
---
```

- [ ] **Step 2: Build and look for the status icon and tooltip**

Run:

```bash
.venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"; \
grep -c 'md-status--needs-review' site/index.html; \
grep -c 'Needs review' site/index.html
```

Expected: `exit=0`, then two numbers each `1` or greater. The first shows Material rendered the status icon in the nav (the nav is on every page, so `site/index.html` is enough); the second shows the tooltip text from `extra.status` is attached to it (only the first two words are grepped so HTML escaping of the dash cannot cause a false failure).

- [ ] **Step 3: Revert the temporary status**

Run:

```bash
sed -n '4p' docs/ai-development/loops-and-graphs.md
```

Expected: exactly `status: needs-review`. **Only if that is what line 4 says**, run:

```bash
sed -i '4d' docs/ai-development/loops-and-graphs.md && sed -n '1,6p' docs/ai-development/loops-and-graphs.md && grep -c '^status:' docs/ai-development/loops-and-graphs.md
```

Expected: the first six lines shown in Task 3 Step 3 (`---`, title, description, tags, `---`, blank — no `status:` line), then `0`.

- [ ] **Step 4: Confirm the build is clean again**

Run:

```bash
.venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"; grep -c 'md-status' site/index.html
```

Expected: `exit=0` and `0` — no status markup remains.

---

### Task 7: Prototype convention file

**Files:**
- Create: `prototypes/README.md`

- [ ] **Step 1: Create `prototypes/README.md`**

Create `prototypes/README.md` with exactly this content:

```markdown
# Prototypes

Runnable projects that the research in [`docs/`](../docs/) leads to. One folder per topic, mirroring the docs slug, and one folder per prototype inside it:

    prototypes/<topic>/<name>/

`<name>` is a short kebab-case description of what the prototype demonstrates, for example `langgraph-writer-critic`. Each prototype is self-contained: its own `README.md` (what it demonstrates, how to run it, which guide section it illustrates), its own tooling and lockfile, its own language. C#, TypeScript, and Python side by side is expected. There is no root-level build or workspace; a pnpm workspace or a solution file is added only when several same-stack prototypes make it worth it.

The root `.gitignore` ignores `bin/`, `obj/`, `dist/`, `node_modules/`, `.venv/`, and `.env` / `.env.*` (except `.env.example`) at any depth. If a prototype needs one of those tracked — a Node CLI with `bin/cli.js`, a deliberately committed `dist/` demo — add a nested `.gitignore` inside the prototype containing, for example, `!bin/`. The same file is where a prototype ignores anything unusual it produces.

Topic folders are created together with their first prototype, and each prototype is linked from its topic's landing page under `docs/<topic>/index.md`.
```

- [ ] **Step 2: Verify the file exists and the tree is unaffected by it**

Run:

```bash
test -f prototypes/README.md && echo "ok" && .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"
```

Expected: `ok` then `exit=0` (the file is outside `docs/`, so the site does not change).

---

### Task 8: Root README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create `README.md`**

Create `README.md` at the repository root with exactly this content:

````markdown
# Dev Research

Personal research into development concepts and technology: living guides, published as a site, and the prototypes they lead to.

**Site:** <https://mortenbrudvik.github.io/dev-research/>

Each guide is one canonical document per question, revised in place as the topic evolves. Git history is the changelog; every published page shows when it was last updated.

## Layout

```
dev-research/
├── README.md                     this file
├── mkdocs.yml                    site configuration, including the nav
├── requirements.txt              Python packages that build the site
├── .gitignore                    ignore rules for Node, Python, .NET, secrets, and the site output
├── .github/workflows/docs.yml    builds on pull requests and pushes to main; deploys on pushes to main and manual runs
├── docs/                         site source — one folder per topic
│   ├── index.md                  site landing page
│   ├── <topic>/
│   │   ├── index.md              topic landing page: scope, status, guides, prototypes
│   │   └── <guide>.md            one guide per question
│   └── superpowers/              design specs and plans; versioned, not published
└── prototypes/                   runnable projects — one folder per topic, mirroring docs/
    └── <topic>/<name>/           self-contained: own README, tooling, lockfile
```

## Adding a topic

1. Create `docs/<topic>/index.md` with `title:` frontmatter. It contains, in order: a scope paragraph, a **Status** line, a **Guides** list (each guide with its description sentence), and a **Prototypes** list (or "None yet").
2. Add a section to `nav:` in `mkdocs.yml` with the topic's `index.md` as its first entry.
3. Add the topic to the list in `docs/index.md`.

## Adding a guide

1. Create `docs/<topic>/<guide>.md` with frontmatter:

   ```yaml
   ---
   title: <same text as the guide's H1>
   description: <one sentence>
   status: needs-review      # optional — draft | needs-review. Omit when the guide is current.
   tags: [ai, agents]
   ---
   ```

   A guide with a `status` gets an icon and tooltip next to its nav entry; guides without one are current.

2. Add it to the topic's section in `nav:` in `mkdocs.yml`. The strict build fails if you forget.
3. List it in the topic's `index.md` with its description sentence.
4. Write it: one question per guide, a **References** section last. Link to other guides with relative paths (`../other-topic/guide.md#anchor`); link to prototypes with full GitHub URLs; never link into `docs/superpowers/` (excluded pages are not caught by the strict build).
5. Run `mkdocs build --strict` — it must pass.

## Adding a prototype

Create `prototypes/<topic>/<name>/` with its own `README.md` (what it demonstrates, how to run it, which guide section it illustrates), its own tooling and lockfile. There is no root-level build or workspace. Link it from the topic's `index.md`. Details in [`prototypes/README.md`](prototypes/README.md).

## Working on the site locally

```
python -m venv .venv
.venv\Scripts\activate           # PowerShell / cmd — in Git Bash: source .venv/Scripts/activate
pip install -r requirements.txt
mkdocs serve                     # http://127.0.0.1:8000, live reload
mkdocs build --strict            # what CI runs; broken links, broken anchors, and pages missing from the nav fail it
```

Local builds show no "Last update" dates: the git-date plugin only runs in CI, where every file is committed. It is switched on by the `CI` environment variable being exactly `true`, which GitHub Actions sets.

## Deployment

Pushing to `main` runs the `docs` workflow: a strict build, then a deploy to GitHub Pages. Pull requests build only. Manual runs (Actions → docs → Run workflow) build and deploy.

## One-time setup

Do these once, in this order, when first publishing the repository. The local folder is already `git init`-ed on `master` with no commits.

1. `git branch -m main`
2. Review the working tree and commit.
3. `gh repo create mortenbrudvik/dev-research --public --source . --remote origin` — creates the repository and adds `origin`; nothing is pushed yet.
4. Settings → Pages → Build and deployment → Source: **GitHub Actions**. Do this before the first push; if the push lands first, the deploy job fails once — set the source and re-run the workflow from the Actions tab.
5. `git push -u origin main` — runs the workflow and publishes the site.
````

- [ ] **Step 2: Verify the README's internal link resolves and the site is unaffected**

Run:

```bash
test -f prototypes/README.md && echo "link target exists" && .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"
```

Expected: `link target exists` then `exit=0`.

---

### Task 9: GitHub Actions workflow

**Files:**
- Create: `.github/workflows/docs.yml`

- [ ] **Step 1: Create the workflow**

Create `.github/workflows/docs.yml` with exactly this content:

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

- [ ] **Step 2: Parse the workflow as YAML and check its shape**

PyYAML is installed as a MkDocs dependency. Run:

```bash
.venv/Scripts/python -c "import yaml; d=yaml.safe_load(open('.github/workflows/docs.yml')); print(d['name'], list(d['jobs']), d['jobs']['deploy']['needs'], d['jobs']['build']['steps'][0]['uses'], d['jobs']['deploy']['steps'][0]['uses'])"
```

Expected:

```
docs ['build', 'deploy'] build actions/checkout@v7 actions/deploy-pages@v5
```

(A YAML syntax error prints a traceback instead. Note for the curious: PyYAML reads the top-level `on:` key as the boolean `True`, which is a YAML 1.1 quirk and harmless to GitHub.)

- [ ] **Step 3: Confirm the referenced action majors exist**

Run:

```bash
for r in actions/checkout actions/setup-python actions/upload-pages-artifact actions/deploy-pages; do printf "%s: " "$r"; gh api "repos/$r/releases/latest" --jq '.tag_name'; done
```

Expected (majors are what matter; patch numbers may be higher):

```
actions/checkout: v7.0.1
actions/setup-python: v7.0.0
actions/upload-pages-artifact: v5.0.0
actions/deploy-pages: v5.0.0
```

If any major is now higher than what the workflow pins, leave the workflow as is — the pinned majors still exist and run — and mention the newer major in the handoff.

---

### Task 10: Final verification and handoff

No commits. This task confirms the whole tree matches the spec and tells the owner exactly what to do next.

- [ ] **Step 1: Full strict build from a clean output directory**

Run:

```bash
rm -rf site && .venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c 'WARNING -'; .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"
```

Expected: `0` then `exit=0`.

- [ ] **Step 2: Confirm the working tree contains exactly the planned files**

Run:

```bash
git status --short && echo "---- untracked files, expanded ----" && git status --short --untracked-files=all | grep -v '^?? docs/superpowers/'
```

Expected first block (directories collapsed):

```
?? .github/
?? .gitignore
?? README.md
?? docs/
?? mkdocs.yml
?? prototypes/
?? requirements.txt
```

Expected second block (every file except the specs/plans):

```
?? .github/workflows/docs.yml
?? .gitignore
?? README.md
?? docs/ai-development/index.md
?? docs/ai-development/loops-and-graphs.md
?? docs/index.md
?? mkdocs.yml
?? prototypes/README.md
?? requirements.txt
```

Nothing else may appear. In particular `.venv/`, `site/`, and `ai-development-loops-and-graphs.md` (the old path) must be absent. The filtered-out `docs/superpowers/specs/2026-08-25-repo-structure-design.md` and `docs/superpowers/plans/2026-08-25-repo-structure.md` are also new and get committed with everything else.

- [ ] **Step 3: Spot-check the migrated guide is byte-identical below the frontmatter**

Run:

```bash
tail -n +7 docs/ai-development/loops-and-graphs.md | wc -l; tail -1 docs/ai-development/loops-and-graphs.md | cut -c1-60
```

Expected: `729` (the original file's line count) and `*Compiled from a multi-agent research sweep (9 parallel rese` (the provenance footer, still last).

- [ ] **Step 4: Hand off to the owner**

Report to the owner, in this order:

1. The strict build passes locally with zero warnings; `docs/superpowers/` is excluded from the site; the page-status feature was verified and reverted.
2. The exact list of new files from Step 2.
3. The one-time steps, which only the owner can do:
   1. `git branch -m main`
   2. Review the tree and commit.
   3. `gh repo create mortenbrudvik/dev-research --public --source . --remote origin`
   4. GitHub → Settings → Pages → Build and deployment → Source: **GitHub Actions** (before the first push).
   5. `git push -u origin main`, then watch the `docs` workflow; the site appears at https://mortenbrudvik.github.io/dev-research/ with a "Last update" date on the guide.
4. That renaming the local folder from `ai-development` to `dev-research` is optional and should be done outside an active Claude Code session.

---

## Post-execution amendments (2026-08-25)

All ten tasks were executed by subagents and passed spec-compliance and quality review on the first round; a final review over the whole tree found no Critical or Important issues. The reviewers' minor findings were then applied to the tree, the spec, and the content blocks above, so this plan matches the files as they stand:

- `.gitignore`: `site/` → `/site/` (anchored; a prototype may legitimately have its own `site/`). Task 1 Step 4 now passes `site/` with a trailing slash to `git check-ignore`, which is required while the directory does not yet exist.
- `mkdocs.yml`: added `content.action.edit` under `theme.features`; without it Material renders no "edit this page" button and `edit_uri` is inert.
- `README.md`: layout tree lists `.gitignore` and describes the workflow triggers precisely; the local-build note says the date plugin keys on `CI` being exactly `true`; the one-time-setup intro is in the imperative (the steps have not happened yet).
- `prototypes/README.md`: states the `<name>` kebab-case convention and describes the `.env` rules exactly (`.env`, `.env.*`, `.env.example` re-included).
- Expected-output corrections: `python -m mkdocs --version` prints a `python -m` prefix (Task 1 Step 3); the Task 10 Step 3 `cut -c1-60` string was one character short.
- Task 6 notes that `sed -i` on Git Bash rewrites CRLF files as LF and how to guard against it.

Observations recorded but deliberately not acted on: no `.gitattributes` (`core.autocrlf=true` on this machine will print "LF will be replaced by CRLF" on `git add`; harmless); workflow-level `permissions`/`concurrency` and no `timeout-minutes` match GitHub's starter template; the date plugin's CI code path first runs on the owner's first push.
