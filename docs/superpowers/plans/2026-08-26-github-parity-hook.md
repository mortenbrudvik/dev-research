# GitHub-Parity Build Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mkdocs build --strict` fail whenever a guide contains GitHub-flavoured markdown that Python-Markdown would silently render wrong (bare URLs not linked, 2-space nested lists, tables without a blank line, `> [!NOTE]` alerts), per `docs/superpowers/specs/2026-08-26-github-parity-hook-design.md`.

**Architecture:** A MkDocs hook file `hooks/github_parity.py` registered in `mkdocs.yml`. Three pure functions (`find_urls`, `missing_links`, `lint`) do the work and are unit-tested with the standard library; two thin MkDocs event functions call them and log warnings through `mkdocs.plugins.github_parity`, which strict mode counts as failures. `pymdownx.tasklist` and `pymdownx.tilde` close the two syntax gaps that are cheaper to enable than to lint.

**Tech Stack:** Python 3.13 in `.venv` (MkDocs 1.6, Material 9.7, pymdown-extensions already installed), `unittest`, GitHub Actions.

**Owner rule — no commits from the assistant.** No `git add`/`commit`/`push` in any task. Task 6 hands the tree over.

**Shell note.** Commands are Git Bash, run from the repository root `C:\code\prototypes\ai-development`; the venv interpreter is called as `.venv/Scripts/python`. Every `mkdocs build` prints a boxed Material notice about MkDocs 2.0 on stdout; it is not a `WARNING -` line and is ignored.

---

## File map

| Path | Responsibility | Task |
|---|---|---|
| `tests/test_github_parity.py` | Unit tests for the three pure functions | 1 |
| `hooks/github_parity.py` | The hook: pure functions + MkDocs events | 2 |
| `mkdocs.yml` | Register the hook; add `tasklist` and `tilde` | 3 |
| `.github/workflows/docs.yml` | Run the unit tests before the strict build | 5 |
| `README.md`, `CLAUDE.md`, `docs/superpowers/specs/2026-08-25-repo-structure-design.md`, `docs/superpowers/plans/2026-08-25-repo-structure.md` | Document the rule, the command, and keep the repo spec in sync | 5 |

---

### Task 1: Unit tests (red)

**Files:**
- Create: `tests/test_github_parity.py`

- [ ] **Step 1: Create the test file**

Create `tests/test_github_parity.py` with exactly this content:

```python
"""Unit tests for hooks/github_parity.py.

Run: python -m unittest discover -s tests -v
"""

import importlib.util
import pathlib
import unittest

HOOK = pathlib.Path(__file__).resolve().parents[1] / "hooks" / "github_parity.py"
_spec = importlib.util.spec_from_file_location("github_parity", HOOK)
gp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gp)


class FindUrls(unittest.TestCase):
    def test_bare_url(self):
        self.assertEqual(gp.find_urls("See https://example.com/a for details"), ["https://example.com/a"])

    def test_trailing_period_stripped(self):
        self.assertEqual(gp.find_urls("Read https://example.com/a."), ["https://example.com/a"])

    def test_markdown_link_target(self):
        self.assertEqual(gp.find_urls("[docs](https://example.com/a) and more"), ["https://example.com/a"])

    def test_url_with_ampersand(self):
        self.assertEqual(gp.find_urls("https://example.com/?a=1&b=2"), ["https://example.com/?a=1&b=2"])

    def test_inline_code_skipped(self):
        self.assertEqual(gp.find_urls("run `curl https://example.com/a` now"), [])

    def test_fenced_block_skipped(self):
        text = "before\n```bash\ncurl https://example.com/a\n```\nafter https://example.com/b"
        self.assertEqual(gp.find_urls(text), ["https://example.com/b"])

    def test_two_urls_on_one_line(self):
        self.assertEqual(
            gp.find_urls("https://a.example and https://b.example"),
            ["https://a.example", "https://b.example"],
        )


class MissingLinks(unittest.TestCase):
    def test_bare_url_not_linked_is_reported(self):
        html = "<p>See https://example.com/a for details</p>"
        self.assertEqual(
            gp.missing_links("See https://example.com/a for details", html),
            ["https://example.com/a"],
        )

    def test_linked_url_is_not_reported(self):
        html = '<p>See <a href="https://example.com/a">https://example.com/a</a></p>'
        self.assertEqual(gp.missing_links("See https://example.com/a", html), [])

    def test_escaped_ampersand_matches(self):
        html = '<a href="https://example.com/?a=1&amp;b=2">x</a>'
        self.assertEqual(gp.missing_links("https://example.com/?a=1&b=2", html), [])


class Lint(unittest.TestCase):
    def test_two_space_nested_list_flagged_with_line_number(self):
        problems = gp.lint("- parent\n  - child")
        self.assertEqual([line for line, _ in problems], [2])
        self.assertIn("indented 2 spaces", problems[0][1])

    def test_four_space_nested_list_ok(self):
        self.assertEqual(gp.lint("- parent\n    - child"), [])

    def test_six_space_nested_list_flagged(self):
        self.assertEqual([line for line, _ in gp.lint("- a\n    - b\n      - c")], [3])

    def test_top_level_list_ok(self):
        self.assertEqual(gp.lint("- a\n- b\n1. c"), [])

    def test_table_after_text_line_flagged(self):
        problems = gp.lint("Some text\n| a | b |\n|---|---|")
        self.assertEqual(problems, [(2, "table must be preceded by a blank line")])

    def test_table_after_blank_line_ok(self):
        self.assertEqual(gp.lint("Some text\n\n| a | b |\n|---|---|"), [])

    def test_table_after_closing_fence_flagged(self):
        problems = gp.lint("```\ncode\n```\n| a | b |\n|---|---|")
        self.assertEqual([line for line, _ in problems], [4])

    def test_github_alert_flagged(self):
        problems = gp.lint("> [!NOTE]\n> text")
        self.assertEqual([line for line, _ in problems], [1])
        self.assertIn("admonition", problems[0][1])

    def test_lowercase_alert_flagged(self):
        self.assertEqual([line for line, _ in gp.lint("> [!tip]")], [1])

    def test_patterns_inside_fence_ignored(self):
        text = "```\n- a\n  - b\ntext\n| a |\n> [!NOTE]\n```"
        self.assertEqual(gp.lint(text), [])

    def test_frontmatter_yaml_list_ignored(self):
        text = "---\ntitle: x\ntags:\n  - ai\n---\n\n# Heading"
        self.assertEqual(gp.lint(text), [])

    def test_clean_document(self):
        text = "# Title\n\nText with https://example.com.\n\n| a | b |\n|---|---|\n\n- one\n    - two\n"
        self.assertEqual(gp.lint(text), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests and confirm they fail because the hook does not exist**

Run:

```bash
.venv/Scripts/python -m unittest discover -s tests -v 2>&1 | tail -5; echo "exit=${PIPESTATUS[0]}"
```

Expected: the output ends with a traceback containing `FileNotFoundError` (or `No such file or directory`) mentioning `hooks\github_parity.py`, then `exit=1`. That is the red state: the tests load but the module under test is missing. If instead the output says `Ran 0 tests`, discovery did not find the file — check its name and location.

---

### Task 2: The hook (green)

**Files:**
- Create: `hooks/github_parity.py`

- [ ] **Step 1: Create the hook**

Create `hooks/github_parity.py` with exactly this content:

```python
"""MkDocs hook: fail the strict build when GitHub-flavoured markdown would silently render wrong.

Registered in mkdocs.yml under `hooks:`. Two checks:

1. Every http(s) URL in a page's markdown (outside code) is a link in the rendered HTML.
2. The source does not use GitHub-only syntax that Python-Markdown degrades silently:
   nested lists not indented by multiples of 4, tables without a blank line before them,
   and `> [!NOTE]`-style alerts.

Warnings go through the `mkdocs.plugins.*` logger, so `mkdocs build --strict` fails on them.
The pure functions (find_urls, missing_links, lint) have no MkDocs dependency and are unit-tested
by tests/test_github_parity.py.
"""

from __future__ import annotations

import html
import logging
import re
from pathlib import Path

log = logging.getLogger("mkdocs.plugins.github_parity")

FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`\n]*`")
URL = re.compile(r"""https?://[^\s<>"'`\[\]()]+""")
TRAILING_PUNCTUATION = ".,;:!?"
HREF = re.compile(r'href="([^"]*)"')
LIST_MARKER = re.compile(r"^( *)(?:[-*+]|\d+\.) ")
TABLE_ROW = re.compile(r"^\|")
GITHUB_ALERT = re.compile(r"^> \[!(?:NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]", re.IGNORECASE)


def _lines(markdown: str):
    """Yield (line_number, line, in_fence) for every line. Fence lines themselves report in_fence=True."""
    in_fence = False
    for number, line in enumerate(markdown.splitlines(), start=1):
        if FENCE.match(line):
            in_fence = not in_fence
            yield number, line, True
            continue
        yield number, line, in_fence


def find_urls(markdown: str) -> list[str]:
    """http(s) URLs outside fenced blocks and inline code, trailing punctuation stripped, in order."""
    urls: list[str] = []
    for _, line, in_fence in _lines(markdown):
        if in_fence:
            continue
        for match in URL.finditer(INLINE_CODE.sub(" ", line)):
            urls.append(match.group(0).rstrip(TRAILING_PUNCTUATION))
    return urls


def missing_links(markdown: str, rendered_html: str) -> list[str]:
    """URLs from the markdown that are not an href in the rendered HTML."""
    hrefs = {html.unescape(href) for href in HREF.findall(rendered_html)}
    return [url for url in find_urls(markdown) if url not in hrefs]


def lint(markdown: str) -> list[tuple[int, str]]:
    """(line number, message) for GitHub-only syntax that Python-Markdown renders wrong.

    Skips fenced code blocks and a leading YAML frontmatter block.
    """
    problems: list[tuple[int, str]] = []
    previous = ""
    in_frontmatter = False
    for number, line, in_fence in _lines(markdown):
        if number == 1 and line.strip() == "---":
            in_frontmatter = True
            continue
        if in_frontmatter:
            if line.strip() == "---":
                in_frontmatter = False
                previous = ""
            continue
        if not in_fence:
            marker = LIST_MARKER.match(line)
            if marker and len(marker.group(1)) % 4:
                problems.append((
                    number,
                    f"list item indented {len(marker.group(1))} spaces; Python-Markdown needs multiples of 4 to nest",
                ))
            if TABLE_ROW.match(line) and previous.strip() and not TABLE_ROW.match(previous):
                problems.append((number, "table must be preceded by a blank line"))
            if GITHUB_ALERT.match(line):
                problems.append((number, "GitHub alert syntax renders as plain text; use a '!!! note' admonition"))
        previous = line
    return problems


# --- MkDocs events ---------------------------------------------------------------------------


def on_page_markdown(markdown, page, config, files):
    """Check 2 on the source file, so reported line numbers match the editor (frontmatter included)."""
    if not page.file.abs_src_path:
        return None
    source = Path(page.file.abs_src_path).read_text(encoding="utf-8")
    for number, message in lint(source):
        log.warning("%s:%d: %s", page.file.src_path, number, message)
    return None


def on_page_content(html_content, page, config, files):
    """Check 1: every URL in the page's markdown is an href in the rendered HTML."""
    for url in missing_links(page.markdown or "", html_content):
        log.warning("%s: URL is not a link in the rendered page: %s", page.file.src_path, url)
    return None
```

- [ ] **Step 2: Run the tests and confirm all 22 pass**

Run:

```bash
.venv/Scripts/python -m unittest discover -s tests -v 2>&1 | tail -4; echo "exit=${PIPESTATUS[0]}"
```

Expected:

```
----------------------------------------------------------------------
Ran 22 tests in 0.0NNs

OK
exit=0
```

If any test fails, the hook does not match the spec — fix the hook, not the test.

- [ ] **Step 3: Confirm the hook has no stray files and imports cleanly on its own**

Run:

```bash
.venv/Scripts/python -c "import importlib.util as u, pathlib as p; s=u.spec_from_file_location('gp', p.Path('hooks/github_parity.py')); m=u.module_from_spec(s); s.loader.exec_module(m); print(m.log.name, len(m.lint('- a\n  - b')))" && git status --short --untracked-files=all
```

Expected:

```
mkdocs.plugins.github_parity 1
?? hooks/github_parity.py
?? tests/test_github_parity.py
```

plus the four already-modified files from the magiclink fix (`M CLAUDE.md`, `M docs/superpowers/plans/2026-08-25-repo-structure.md`, `M docs/superpowers/specs/2026-08-25-repo-structure-design.md`, `M mkdocs.yml`) and the new spec/plan under `docs/superpowers/`. No `__pycache__` may appear (it is gitignored).

---

### Task 3: Wire the hook into the build and prove check 1 bites

**Files:**
- Modify: `mkdocs.yml`

- [ ] **Step 1: Register the hook and add the two extensions**

Using the Edit tool, in `mkdocs.yml` replace

```yaml
validation:
  omitted_files: warn
```

with

```yaml
hooks:
  - hooks/github_parity.py   # fails the strict build on GitHub-only markdown that would render wrong

validation:
  omitted_files: warn
```

and replace

```yaml
  - pymdownx.magiclink          # bare URLs become links, as on GitHub
  - pymdownx.superfences:
```

with

```yaml
  - pymdownx.magiclink          # bare URLs become links, as on GitHub
  - pymdownx.tasklist:          # - [ ] task lists, as on GitHub
      custom_checkbox: true
  - pymdownx.tilde              # ~~strikethrough~~, as on GitHub
  - pymdownx.superfences:
```

- [ ] **Step 2: Strict build still passes on the current content**

Run:

```bash
rm -rf site && .venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c 'WARNING -'; .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"; grep -o '<a [^>]*href="http[^"]*"' site/ai-development/loops-and-graphs/index.html | grep -vc 'github.com/mortenbrudvik'
```

Expected: `0`, `exit=0`, `32` (the guide's external links are all still rendered). If a `URL is not a link in the rendered page` warning appears here, `magiclink` delimited that URL differently from `find_urls` — capture the URL from the warning and the matching `href="…"` from `site/ai-development/loops-and-graphs/index.html` and report DONE_WITH_CONCERNS with both strings; do not change the hook to make it pass.

- [ ] **Step 3: Mutation — remove magiclink and confirm the build fails with 31 URL warnings**

Using the Edit tool, in `mkdocs.yml` replace

```yaml
  - pymdownx.magiclink          # bare URLs become links, as on GitHub
```

with

```yaml
  # MUTATION TEST — remove me
```

Then run:

```bash
.venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c 'URL is not a link in the rendered page'; .venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -E 'Aborted with|loops-and-graphs.md: URL' | tail -3 | cut -c1-160; .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"
```

Expected: `31`; two lines of the form `WARNING -  docs/ai-development/loops-and-graphs.md: URL is not a link in the rendered page: https://…` followed by `Aborted with 31 warnings in strict mode!` (order may vary); `exit=1`.

- [ ] **Step 4: Restore magiclink and confirm the build is clean again**

Using the Edit tool, replace

```yaml
  # MUTATION TEST — remove me
```

with

```yaml
  - pymdownx.magiclink          # bare URLs become links, as on GitHub
```

Then run:

```bash
grep -c 'MUTATION' mkdocs.yml; .venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c 'WARNING -'; .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"
```

Expected: `0`, `0`, `exit=0`.

---

### Task 4: Prove check 2 bites

**Files:**
- Create then delete: `docs/ai-development/scratch.md`
- Modify then revert: `mkdocs.yml` (one nav line)

- [ ] **Step 1: Create a scratch page with the three bad patterns**

Create `docs/ai-development/scratch.md` with exactly this content:

```markdown
---
title: Scratch
---

# Scratch

- parent
  - child indented two spaces

A paragraph directly followed by a table
| a | b |
|---|---|

> [!NOTE]
> A GitHub alert.
```

- [ ] **Step 2: Add it to the nav**

Using the Edit tool, in `mkdocs.yml` replace

```yaml
      - ai-development/loops-and-graphs.md
```

with

```yaml
      - ai-development/loops-and-graphs.md
      - ai-development/scratch.md
```

- [ ] **Step 3: Build and confirm exactly three lint warnings with the right lines**

Run:

```bash
.venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -E 'scratch.md:[0-9]+:' | sed 's/^.*scratch.md:/scratch.md:/' | sort; .venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c 'WARNING -'; .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"
```

Expected:

```
scratch.md:11: table must be preceded by a blank line
scratch.md:14: GitHub alert syntax renders as plain text; use a '!!! note' admonition
scratch.md:8: list item indented 2 spaces; Python-Markdown needs multiples of 4 to nest
3
exit=1
```

(Line 8 is the 2-space child, line 11 the first table row, line 14 the alert — counted from the top of the file including the three frontmatter lines, which is what the editor shows. The order is `sort`'s string order.)

- [ ] **Step 4: Remove the scratch page and the nav line; confirm the build is clean**

Run:

```bash
rm docs/ai-development/scratch.md
```

Using the Edit tool, in `mkdocs.yml` replace

```yaml
      - ai-development/loops-and-graphs.md
      - ai-development/scratch.md
```

with

```yaml
      - ai-development/loops-and-graphs.md
```

Then run:

```bash
test ! -e docs/ai-development/scratch.md && echo "scratch gone"; grep -c scratch mkdocs.yml; rm -rf site && .venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c 'WARNING -'; .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"; test ! -e site/ai-development/scratch && echo "not in site"
```

Expected:

```
scratch gone
0
0
exit=0
not in site
```

---

### Task 5: CI step and documentation

**Files:**
- Modify: `.github/workflows/docs.yml`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-08-25-repo-structure-design.md`
- Modify: `docs/superpowers/plans/2026-08-25-repo-structure.md`

- [ ] **Step 1: Run the unit tests in CI before the build**

Using the Edit tool, in `.github/workflows/docs.yml` replace

```yaml
      - run: pip install -r requirements.txt
      - run: mkdocs build --strict
```

with

```yaml
      - run: pip install -r requirements.txt
      - run: python -m unittest discover -s tests -v
      - run: mkdocs build --strict
```

Then verify it still parses:

```bash
.venv/Scripts/python -c "import yaml; d=yaml.safe_load(open('.github/workflows/docs.yml')); print([s.get('run') for s in d['jobs']['build']['steps'] if 'run' in s])"
```

Expected: `['pip install -r requirements.txt', 'python -m unittest discover -s tests -v', 'mkdocs build --strict']`

- [ ] **Step 2: README — layout tree, guide rule, test command**

Using the Edit tool on `README.md`, make these three replacements.

Replace

```
├── .github/workflows/docs.yml    builds on pull requests and pushes to main; deploys on pushes to main and manual runs
```

with

```
├── .github/workflows/docs.yml    runs the unit tests and a strict build on pull requests and pushes to main; deploys on pushes to main and manual runs
├── hooks/github_parity.py        build hook: fails the strict build on GitHub-only markdown that would render wrong
├── tests/                        unit tests for the hook
```

Replace

```
4. Write it: one question per guide, a **References** section last. Link to other guides with relative paths (`../other-topic/guide.md#anchor`); link to prototypes with full GitHub URLs; never link into `docs/superpowers/` (excluded pages are not caught by the strict build).
```

with

```
4. Write it: one question per guide, a **References** section last. Link to other guides with relative paths (`../other-topic/guide.md#anchor`); link to prototypes with full GitHub URLs; never link into `docs/superpowers/` (excluded pages are not caught by the strict build). Guides are GitHub-flavoured markdown, and the build fails if a URL is not rendered as a link, a nested list is not indented by 4, a table has no blank line before it, or a GitHub alert (`> [!NOTE]`) is used — write `!!! note` instead.
```

Replace

```
mkdocs build --strict            # what CI runs; broken links, broken anchors, and pages missing from the nav fail it
```

with

```
mkdocs build --strict            # what CI runs; broken links, broken anchors, pages missing from the nav, and GitHub-only markdown fail it
python -m unittest discover -s tests   # unit tests for the build hook in hooks/
```

- [ ] **Step 3: CLAUDE.md — command, structure, rule**

Using the Edit tool on `CLAUDE.md`, make these three replacements.

Replace

```
Without activating: `.venv/Scripts/python -m mkdocs build --strict`.
```

with

```
Without activating: `.venv/Scripts/python -m mkdocs build --strict`.

Unit tests for the build hook (stdlib `unittest`, no extra dependency; CI runs them before the build): `python -m unittest discover -s tests -v`. Run a single case with `python -m unittest tests.test_github_parity.Lint.test_two_space_nested_list_flagged_with_line_number`.
```

Replace

```
- `docs/superpowers/` — design specs and plans. Versioned but **excluded from the site** (`exclude_docs`). Never link to it from a guide: MkDocs logs links to excluded files at INFO, so the strict build will not catch the resulting 404.
```

with

```
- `docs/superpowers/` — design specs and plans. Versioned but **excluded from the site** (`exclude_docs`). Never link to it from a guide: MkDocs logs links to excluded files at INFO, so the strict build will not catch the resulting 404.
- `hooks/github_parity.py` + `tests/` — a MkDocs hook (registered under `hooks:` in `mkdocs.yml`) that runs inside every build and makes `--strict` fail on GitHub-flavoured markdown that Python-Markdown would silently degrade. Three pure functions (`find_urls`, `missing_links`, `lint`) carry the logic; extend the lint there and add a test case when a new divergence is found.
```

Replace

```
**Links.** Bare URLs are autolinked by `pymdownx.magiclink` (Python-Markdown does not do this on its own, unlike GitHub) — the References sections rely on it. Between docs: relative markdown links (`../other-topic/guide.md#anchor`).
```

with

```
**Links and GitHub-style markdown.** Bare URLs are autolinked by `pymdownx.magiclink` (Python-Markdown does not do this on its own, unlike GitHub) — the References sections rely on it, and the hook fails the build if any URL is not a link in the rendered page. The hook also rejects list markers indented by a non-multiple of 4 (2-space nesting silently flattens), tables without a blank line before them (they become paragraph text), and `> [!NOTE]` alerts (write `!!! note`). Task lists and `~~strikethrough~~` render via `pymdownx.tasklist`/`pymdownx.tilde`. Between docs: relative markdown links (`../other-topic/guide.md#anchor`).
```

- [ ] **Step 4: Keep the repository spec in sync**

Using the Edit tool on `docs/superpowers/specs/2026-08-25-repo-structure-design.md`, make these four replacements.

Replace

```
validation:
  omitted_files: warn
```

with

```
hooks:
  - hooks/github_parity.py   # fails the strict build on GitHub-only markdown that would render wrong

validation:
  omitted_files: warn
```

Replace

```
  - pymdownx.magiclink          # bare URLs become links, as on GitHub
  - pymdownx.superfences:
```

with

```
  - pymdownx.magiclink          # bare URLs become links, as on GitHub
  - pymdownx.tasklist:          # - [ ] task lists, as on GitHub
      custom_checkbox: true
  - pymdownx.tilde              # ~~strikethrough~~, as on GitHub
  - pymdownx.superfences:
```

Replace

```
      - run: pip install -r requirements.txt
      - run: mkdocs build --strict
```

with

```
      - run: pip install -r requirements.txt
      - run: python -m unittest discover -s tests -v
      - run: mkdocs build --strict
```

Replace

```
- **`pymdownx.magiclink`** autolinks bare URLs.
```

with

```
- **`hooks/github_parity.py`** (design: `2026-08-26-github-parity-hook-design.md`) runs inside every build and fails `--strict` when a URL is not a link in the rendered page or the source uses GitHub-only syntax that Python-Markdown degrades silently. Its stdlib unit tests under `tests/` run in CI before the build.
- **`pymdownx.magiclink`** autolinks bare URLs.
```

- [ ] **Step 5: Note the change in the repository plan's amendments**

Using the Edit tool on `docs/superpowers/plans/2026-08-25-repo-structure.md`, replace

```
- 2026-08-26, after first publish: the guide's 31 bare URLs rendered as plain text because Python-Markdown, unlike GitHub, does not autolink them. Added `pymdownx.magiclink` to `markdown_extensions` (Task 2 block updated) rather than rewriting the guide, so GitHub-style bare URLs work in every future guide.
```

with

```
- 2026-08-26, after first publish: the guide's 31 bare URLs rendered as plain text because Python-Markdown, unlike GitHub, does not autolink them. Added `pymdownx.magiclink` to `markdown_extensions` (Task 2 block updated) rather than rewriting the guide, so GitHub-style bare URLs work in every future guide.
- 2026-08-26, follow-up: to stop that class of bug recurring, `hooks/github_parity.py` + `tests/` were added and `mkdocs.yml` gained `hooks:`, `pymdownx.tasklist`, and `pymdownx.tilde`; CI runs the unit tests before the build. Spec and plan: `2026-08-26-github-parity-hook-design.md` / `2026-08-26-github-parity-hook.md`. The Task 2 and Task 9 content blocks above are superseded by the current `mkdocs.yml` and `docs.yml`.
```

- [ ] **Step 6: Verify the docs edits landed and the README's internal link still resolves**

Run:

```bash
grep -c 'github_parity' README.md CLAUDE.md docs/superpowers/specs/2026-08-25-repo-structure-design.md docs/superpowers/plans/2026-08-25-repo-structure.md .github/workflows/docs.yml; test -f prototypes/README.md && echo "readme link ok"
```

Expected (a count may be higher if a file mentions it on more lines; only `docs.yml` is zero):

```
README.md:1
CLAUDE.md:2
docs/superpowers/specs/2026-08-25-repo-structure-design.md:2
docs/superpowers/plans/2026-08-25-repo-structure.md:1
.github/workflows/docs.yml:0
readme link ok
```

(`docs.yml` legitimately contains no `github_parity` string — the CI step is the `unittest` command.)

---

### Task 6: Final verification and handoff

No commits.

- [ ] **Step 1: Tests and strict build from clean**

Run:

```bash
.venv/Scripts/python -m unittest discover -s tests 2>&1 | tail -3; rm -rf site && .venv/Scripts/python -m mkdocs build --strict 2>&1 | grep -c 'WARNING -'; .venv/Scripts/python -m mkdocs build --strict >/dev/null 2>&1; echo "exit=$?"
```

Expected: `Ran 22 tests …` / `OK`, then `0`, then `exit=0`.

- [ ] **Step 2: Working tree contains exactly the intended changes**

Run:

```bash
git status --short --untracked-files=all
```

Expected:

```
 M .github/workflows/docs.yml
 M CLAUDE.md
 M README.md
 M docs/superpowers/plans/2026-08-25-repo-structure.md
 M docs/superpowers/specs/2026-08-25-repo-structure-design.md
 M mkdocs.yml
?? docs/superpowers/plans/2026-08-26-github-parity-hook.md
?? docs/superpowers/specs/2026-08-26-github-parity-hook-design.md
?? hooks/github_parity.py
?? tests/test_github_parity.py
```

Nothing else: no `scratch.md`, no `site/`, no `__pycache__`, no `MUTATION` string anywhere (`grep -rn MUTATION mkdocs.yml` prints nothing).

- [ ] **Step 3: Hand off**

Report: the 22 unit tests pass; the strict build is clean; both mutation checks demonstrated the hook fails the build (31 URL warnings without magiclink; 3 file:line lint warnings on the scratch page) and were reverted; the exact file list above is ready for the owner to review and commit — after which the `docs` workflow will run the tests, build, and redeploy with clickable references.

---

## Post-execution amendments (2026-08-26)

All six tasks were executed by subagents and passed spec-compliance and quality review on the first round; the final reviewer independently re-ran both mutations and rated the tree ready. The reviewers also probed the hook beyond the spec and reproduced several false positives in real MkDocs builds, so the hook was **hardened** immediately afterwards (the Task 1 and Task 2 content blocks above are superseded by `tests/test_github_parity.py` and `hooks/github_parity.py` as committed; the spec's sections 2.1–2.3, 2.5, and 6 were updated to match):

- Check 1: rendered targets now include `src` (remote images), a target that starts with the URL counts (parenthesised URLs written as `<url>`/`[text](url)` pass), trailing `*_~` are stripped like sentence punctuation (`**url**` passes), multi-backtick code spans are recognised, fences follow CommonMark (same character, at least the opener's length — ```` can wrap ```), CRLF is normalised.
- Check 2: frontmatter may close with `...`; an unclosed block no longer silently disables the lint; a BOM is ignored; a table directly after a heading is not flagged (it renders correctly); `>[!NOTE]` and nested `> > [!NOTE]` are flagged.
- Events: source is read via `page.file.content_string` (BOM-safe), warnings are prefixed `github_parity: ` via `get_plugin_logger`, and locations are `docs/<src_uri>` with forward slashes on every platform.
- `pymdownx.tilde` is configured with `subscript: false` (GitHub has no subscript syntax).
- Tests grew from 22 to 46 to pin every case above. Verified after hardening: strict build clean with 32 external links; mutation 1 → 31 warnings; mutation 2 → the three expected `file:line` hits with a heading-then-table case correctly not flagged.
- Task 3 Step 3's command used `head -3`, which could never show the trailing `Aborted with` line; changed to `tail -3`.
- README/CLAUDE.md wording fixed: "indented by a multiple of 4", "a table follows a text line without a blank line", CI runs the unit tests before the build (also on manual runs); the stale "There is no other test suite." sentence in CLAUDE.md removed; the repo-structure spec's layout tree and section 7 gained the hook, tests, and the unit-test command.
