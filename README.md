# Dev Research

Personal research into development concepts and technology: living guides, published as a site, and the prototypes they lead to.

**Site:** <https://mortenbrudvik.github.io/dev-research/>

Each guide is one canonical document per question, revised in place as the topic evolves. Git history is the changelog; every published page shows when it was last updated.

## Layout

```
dev-research/
├── README.md                     this file
├── serve.ps1                     local wiki: creates .venv, installs deps, mkdocs serve --open
├── mkdocs.yml                    site configuration, including the nav
├── requirements.txt              Python packages that build the site
├── .gitignore                    ignore rules for Node, Python, .NET, secrets, and the site output
├── .github/workflows/docs.yml    runs the unit tests and a strict build on pull requests, pushes to main, and manual runs; deploys on pushes to main and manual runs
├── hooks/github_parity.py        build hook: fails the strict build on GitHub-only markdown that would render wrong
├── tests/                        unit tests for the hook
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
4. Write it: one question per guide, a **References** section last. Link to other guides with relative paths (`../other-topic/guide.md#anchor`); link to prototypes with full GitHub URLs; never link into `docs/superpowers/` (excluded pages are not caught by the strict build). Guides are GitHub-flavoured markdown, and the build fails if a URL is not rendered as a link, a nested list is not indented by a multiple of 4, a table follows a text line without a blank line, or a GitHub alert (`> [!NOTE]`) is used — write `!!! note` instead.
5. Run `mkdocs build --strict` — it must pass.

## Adding a prototype

Create `prototypes/<topic>/<name>/` with its own `README.md` (what it demonstrates, how to run it, which guide section it illustrates), its own tooling and lockfile. There is no root-level build or workspace. Link it from the topic's `index.md`. Details in [`prototypes/README.md`](prototypes/README.md).

## Working on the site locally

```
.\serve.ps1                      # creates .venv if needed, installs deps, opens http://127.0.0.1:8000 with live reload
```

Equivalent by hand:

```
python -m venv .venv
.venv\Scripts\activate           # PowerShell / cmd — in Git Bash: source .venv/Scripts/activate
pip install -r requirements.txt
mkdocs serve                     # http://127.0.0.1:8000, live reload
mkdocs build --strict            # what CI runs; broken links, broken anchors, pages missing from the nav, and GitHub-only markdown fail it
python -m unittest discover -s tests   # unit tests for the build hook in hooks/
```

Local builds show no "Last update" dates: the git-date plugin only runs in CI, where every file is committed. It is switched on by the `CI` environment variable being exactly `true`, which GitHub Actions sets.

## Deployment

Pushing to `main` runs the `docs` workflow: the unit tests, a strict build, then a deploy to GitHub Pages. Pull requests build only. Manual runs (Actions → docs → Run workflow) build and deploy.

## One-time setup

Do these once, in this order, when first publishing the repository. The local folder is already `git init`-ed on `master` with no commits.

1. `git branch -m main`
2. Review the working tree and commit.
3. `gh repo create mortenbrudvik/dev-research --public --source . --remote origin` — creates the repository and adds `origin`; nothing is pushed yet.
4. Settings → Pages → Build and deployment → Source: **GitHub Actions**. Do this before the first push; if the push lands first, the deploy job fails once — set the source and re-run the workflow from the Actions tab.
5. `git push -u origin main` — runs the workflow and publishes the site.
