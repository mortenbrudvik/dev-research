# GitHub-parity build hook — design

**Date:** 2026-08-26
**Status:** approved and implemented 2026-08-26; hardened the same day after the implementation reviews probed edge cases (see the "Hardening" notes in sections 2.2, 2.3, and 6)
**Scope:** make `mkdocs build --strict` fail whenever a guide contains GitHub-flavoured markdown that Python-Markdown would silently render wrong, so the "references rendered as plain text" bug of 2026-08-26 cannot recur.

## 1. Problem

The guides are written GitHub-style. GitHub and Python-Markdown (MkDocs' engine) disagree in several places, and every disagreement degrades *silently* — the strict build only validates links that already are links, so it saw nothing wrong when all 31 references in `loops-and-graphs.md` came out as plain text. The known divergences:

| GitHub renders | Python-Markdown does | Handled by |
|---|---|---|
| bare `https://…` as a link | plain text | `pymdownx.magiclink` (already added) **+ check 1** |
| list nested with 2 spaces | flattens into the parent list | check 2a |
| table directly after a paragraph line | paragraph text | check 2b |
| `> [!NOTE]` alerts | blockquote with literal `[!NOTE]` | check 2c |
| `- [ ]` task lists | literal brackets | `pymdownx.tasklist` |
| `~~strikethrough~~` | literal tildes | `pymdownx.tilde` |

## 2. Solution

A MkDocs **hook** — a plain Python file registered in `mkdocs.yml` — that runs inside every build and logs warnings, which `--strict` turns into failures. No new command, no new CI build step, no new dependency.

### 2.1 `hooks/github_parity.py`

Logger: `mkdocs.plugins.get_plugin_logger("github_parity")` (falls back to `logging.getLogger("mkdocs.plugins.github_parity")` when MkDocs is not importable, i.e. in the unit tests). Either way the logger lives under `mkdocs.`, so warnings are counted by MkDocs' strict-mode handler; inside a build every message is prefixed `github_parity: `.

Two MkDocs events:

- `on_page_markdown(markdown, page, config, files)` — runs **check 2** against the page's source as MkDocs read it (`page.file.content_string`, BOM-safe; falls back to reading `abs_src_path` as `utf-8-sig`), so reported line numbers match the editor, frontmatter included. Returns `None` (markdown unchanged).
- `on_page_content(html, page, config, files)` — runs **check 1** against the `markdown` MkDocs already passed through `page.markdown` and the rendered `html`. Returns `None`.

Warning locations are `<docs_dir name>/<page.file.src_uri>` — forward slashes on every platform and clickable from the repository root, e.g. `docs/ai-development/loops-and-graphs.md`.

Pure functions, unit-tested, no MkDocs imports:

```python
def find_urls(markdown: str) -> list[str]
    # http(s):// URLs outside fenced code blocks and inline code spans,
    # trailing .,;:!? stripped. Order preserved, duplicates kept.

def missing_links(markdown: str, rendered_html: str) -> list[str]
    # URLs from find_urls that do not appear (after html.unescape) as an
    # href="..." value in rendered_html.

def lint(markdown: str) -> list[tuple[int, str]]
    # (1-based line number, message) for each finding of check 2,
    # ignoring lines inside fenced code blocks.
```

Warning formats (one line each, actionable):

- check 1: `docs/ai-development/loops-and-graphs.md: URL is not a link in the rendered page: https://…`
- check 2: `docs/ai-development/loops-and-graphs.md:214: list item indented 2 spaces; Python-Markdown needs multiples of 4 to nest`

### 2.2 Check 1 — every URL is a link

- URL pattern: `https?://[^\s<>"'`\[\]()]+`; then strip trailing `.,;:!?*_~` — sentence punctuation plus the emphasis delimiters of `**url**`, `*url*`, `_url_`, `~~url~~`, which magiclink and GitHub also leave out of the link. Parentheses are excluded so `[text](https://…)` captures exactly the target.
- Fenced code blocks and inline code spans are ignored: a URL in code is meant to stay text. Fences follow CommonMark — a run of three or more backticks or tildes opens a block and only a run of the same character at least as long closes it, so a ```` fence can wrap a ``` example. Code spans use N backticks on both sides (``` ``a `b` c`` ``` is one span).
- Rendered targets are collected from both `href="…"` and `src="…"` (a remote image is rendered content, not a missing link) and `html.unescape`d so `&amp;` matches `&`.
- A URL passes if some rendered target equals it **or starts with it**. The prefix rule exists for URLs containing parentheses, which the pattern truncates at the first `(`: written as `<url>` or `[text](url)` they render with the full href and pass. The cost is a theoretical miss when a bare `https://x` is unlinked while a longer `https://x/y` is linked on the same page.
- CRLF input is normalised; a leading BOM is ignored.
- Missing URL → one warning per occurrence.

*Hardening (2026-08-26):* the trailing-delimiter set, the CommonMark fence rule, multi-backtick spans, `src` targets, and prefix matching were added after the implementation reviews reproduced false positives for each in real MkDocs builds.

### 2.3 Check 2 — GitHub-only syntax that degrades

Applied line by line to the source file, skipping fenced code blocks (same CommonMark rule as check 1) and a leading YAML frontmatter block — `---` on line 1 closed by `---` or `...`, the two closers MkDocs accepts; an unclosed block is not frontmatter and nothing is skipped, so the lint can never be silently disabled. A leading BOM is ignored. `prev` tracks the previous line including fence lines (a table straight after a closing fence also fails to parse).

- **2a nested-list indent:** a line matching `^( *)([-*+]|\d+\.) ` whose indent length is not a multiple of 4 → `list item indented N spaces; Python-Markdown needs multiples of 4 to nest`.
- **2b table blank line:** a line starting with `|` whose `prev` is non-blank, does not start with `|`, and is not an ATX heading → `table must be preceded by a blank line`. (Python-Markdown renders a table directly after a heading correctly, so that case is exempt; after a paragraph line it becomes paragraph text.)
- **2c GitHub alert:** `^ {0,3}(?:>\s*)+\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]` (case-insensitive; covers `>[!NOTE]` without a space and nested `> > [!NOTE]`) → `GitHub alert syntax renders as plain text; use a '!!! note' admonition`.

*Hardening (2026-08-26):* the frontmatter rules, the heading exemption, and the widened alert pattern were added after the implementation reviews.

### 2.4 `mkdocs.yml` changes

```yaml
hooks:
  - hooks/github_parity.py
```

and, under `markdown_extensions`, after `pymdownx.magiclink`:

```yaml
  - pymdownx.tasklist:
      custom_checkbox: true
  - pymdownx.tilde:
      subscript: false          # GitHub has no H~2~O subscript syntax
```

### 2.5 Tests — `tests/test_github_parity.py`

Standard-library `unittest`; the module is loaded with `importlib.util.spec_from_file_location` from `hooks/github_parity.py` (no package layout needed). Run: `python -m unittest discover -s tests -v`.

Cases (46 after hardening):

- `find_urls`: bare URL; `http://`; trailing period and each of `,;:!?` stripped; each of `**…**`, `*…*`, `_…_`, `~~…~~` stripped; URL inside prose parentheses; `[text](url)` target; URL with `&`; single- and double-backtick code spans skipped; ```` ``` ````, `~~~`, and a ```` fence wrapping a ``` example skipped; CRLF input; two URLs on one line.
- `missing_links`: bare URL absent from HTML → reported; present as `href` → not reported; `&amp;`-escaped href matches; `<img src>` counts as rendered; parenthesised URL matches a rendered target by prefix; mixed linked/unlinked keeps order and duplicates.
- `lint`: 2-space nested list flagged with the right line number; 4-space not flagged; 6-space flagged; top-level list not flagged; table after a text line flagged; after a blank line, after a table row, as the first line, and after a heading not flagged; table straight after a closing fence flagged; `> [!NOTE]`, lower-case `[!tip]`, `>[!NOTE]`, and nested `> > [!WARNING]` flagged; all three patterns inside ```` ``` ```` and `~~~` fences ignored, mixed markers do not close each other, ```` wrapping ``` handled, indented fence inside a list item handled; frontmatter closed with `---` or `...` skipped, unclosed frontmatter does not disable the lint, BOM before frontmatter ignored, a mid-document `---` rule is not frontmatter; CRLF line numbers match the editor; clean document → empty list.

### 2.6 CI — `.github/workflows/docs.yml`

One step inserted between `pip install` and `mkdocs build --strict`:

```yaml
      - run: python -m unittest discover -s tests -v
```

### 2.7 Documentation

- `README.md`: "Adding a guide" step 4 gains the rule "Guides are GitHub-flavoured markdown. The build fails if a URL is not rendered as a link, a nested list is not indented by 4, a table has no blank line before it, or a GitHub alert is used (write `!!! note` instead)."; the local commands block gains `python -m unittest discover -s tests`.
- `CLAUDE.md`: the same rule in the Links paragraph, the hook's location, and the test command under Commands.
- `docs/superpowers/specs/2026-08-25-repo-structure-design.md`: section 5 `mkdocs.yml` block and workflow block updated to match; section 7 gains the unit-test command.

## 3. Repository layout after the change

```
hooks/github_parity.py        the hook (section 2.1–2.3)
tests/test_github_parity.py   its unit tests (section 2.5)
mkdocs.yml                    + hooks:, + tasklist, + tilde
.github/workflows/docs.yml    + unittest step
```

`hooks/` and `tests/` are outside `docs/`, so the site is unaffected; `__pycache__/` is already ignored.

## 4. Verification

1. `python -m unittest discover -s tests -v` — all cases pass.
2. `mkdocs build --strict` — still exit 0 with zero `WARNING -` lines on the current content (the existing guide and landing pages were checked against all three lints on 2026-08-26 and are clean).
3. **Mutation: check 1 bites.** Temporarily remove `- pymdownx.magiclink` from `mkdocs.yml`, build: expect 31 `URL is not a link in the rendered page` warnings and `Aborted with 31 warnings in strict mode!`. Restore.
4. **Mutation: check 2 bites.** Temporarily add `docs/ai-development/scratch.md` (and its nav line) containing a 2-space nested list, a table straight after a paragraph, and `> [!NOTE]`; build: expect exactly three `scratch.md:N:` warnings and a strict abort. Delete the file and the nav line; build is clean again.
5. After push: the `docs` workflow runs the tests and the strict build green; the live guide's references are clickable.

## 5. Owner-visible behaviour

Writing a guide is unchanged. When one of the four patterns slips in, `mkdocs build --strict` (locally or in CI) fails with a file:line message saying what to change.

## 6. Out of scope

- A *bare* URL containing parentheses (Wikipedia-style) — check 1 truncates it at the first `(`, and magiclink stops there too, so write such URLs as `<url>` or `[text](url)`; both pass via the prefix rule (section 2.2).
- URLs that never render but still get reported: inside HTML comments (`<!-- https://… -->`), in unused reference-style definitions (`[ref]: https://…`), in 4-space indented code blocks (use fences), in raw HTML with single-quoted attributes (`<a href='…'>`), and in code spans that span lines. Each fails the build with the URL named in the message, so the fix is obvious when it happens.
- Pipe-less tables (`a | b` / `---|---`): Python-Markdown also accepts them and degrades them the same way, but check 2b only recognises rows that start with `|`. Write tables with leading pipes.
- List continuation paragraphs indented 1–3 spaces (only list *markers* are linted).
- Auto-converting GitHub alerts to admonitions; emoji shortcodes; checking that URLs are reachable.
- Linting `README.md` and `prototypes/README.md`: they render on GitHub, not on the site.
