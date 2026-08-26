"""MkDocs hook: fail the strict build when GitHub-flavoured markdown would silently render wrong.

Registered in mkdocs.yml under `hooks:`. Two checks:

1. Every http(s) URL in a page's markdown (outside code) is a link or image in the rendered HTML.
2. The source does not use GitHub-only syntax that Python-Markdown degrades silently:
   nested lists not indented by multiples of 4, tables that follow text without a blank line,
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

try:  # inside a MkDocs build the messages get a "github_parity: " prefix
    from mkdocs.plugins import get_plugin_logger

    log = get_plugin_logger("github_parity")
except ImportError:  # pure-function use outside MkDocs (unit tests)
    log = logging.getLogger("mkdocs.plugins.github_parity")

# A fence opens with three or more backticks or tildes and closes only with a fence of the
# same character at least as long (CommonMark), so ```` can wrap a ``` example.
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
# Code spans use N backticks on both sides; ``a `b` c`` is one span.
INLINE_CODE = re.compile(r"(`+)(.+?)\1(?!`)")
URL = re.compile(r"""https?://[^\s<>"'`\[\]()]+""")
# Trailing characters that magiclink/GitHub also leave out of the link: sentence punctuation
# and the emphasis delimiters of **url**, *url*, _url_, ~~url~~.
TRAILING_PUNCTUATION = ".,;:!?*_~"
LINK_TARGET = re.compile(r'(?:href|src)="([^"]*)"')
LIST_MARKER = re.compile(r"^( *)(?:[-*+]|\d+\.) ")
TABLE_ROW = re.compile(r"^\|")
HEADING = re.compile(r"^ {0,3}#{1,6}(?:\s|$)")
GITHUB_ALERT = re.compile(r"^ {0,3}(?:>\s*)+\[!(?:NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]", re.IGNORECASE)
FRONTMATTER_CLOSERS = ("---", "...")


def _lines(markdown: str):
    """Yield (line_number, line, in_fence) for every line. Fence lines themselves report in_fence=True.

    Line numbers match the editor: CRLF is normalised and only newlines split lines.
    """
    opener: str | None = None
    for number, line in enumerate(markdown.replace("\r\n", "\n").replace("\r", "\n").split("\n"), start=1):
        fence = FENCE.match(line)
        if fence:
            marker = fence.group(1)
            if opener is None:
                opener = marker
                yield number, line, True
                continue
            if marker[0] == opener[0] and len(marker) >= len(opener):
                opener = None
                yield number, line, True
                continue
        yield number, line, opener is not None


def _frontmatter_line_count(markdown: str) -> int:
    """Number of leading lines taken by a YAML frontmatter block, or 0 if there is none.

    A block starts with `---` on line 1 and closes with `---` or `...` (what MkDocs accepts).
    An unclosed block is not frontmatter, so nothing is skipped.
    """
    lines = markdown.replace("\r\n", "\n").split("\n")
    if not lines or lines[0].strip() != "---":
        return 0
    for index, line in enumerate(lines[1:], start=2):
        if line.strip() in FRONTMATTER_CLOSERS:
            return index
    return 0


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
    """URLs from the markdown that are not an href or src in the rendered HTML.

    A rendered target that merely starts with the URL also counts, so URLs containing
    parentheses (which find_urls truncates at the first "(") still pass when written
    as `<url>` or `[text](url)`.
    """
    targets = {html.unescape(target) for target in LINK_TARGET.findall(rendered_html)}
    return [
        url
        for url in find_urls(markdown)
        if not any(target == url or target.startswith(url) for target in targets)
    ]


def lint(markdown: str) -> list[tuple[int, str]]:
    """(line number, message) for GitHub-only syntax that Python-Markdown renders wrong.

    Skips fenced code blocks and a leading YAML frontmatter block; tolerates a UTF-8 BOM.
    """
    markdown = markdown.lstrip("\ufeff")
    skip = _frontmatter_line_count(markdown)
    problems: list[tuple[int, str]] = []
    previous = ""
    for number, line, in_fence in _lines(markdown):
        if number <= skip:
            continue
        if not in_fence:
            marker = LIST_MARKER.match(line)
            if marker and len(marker.group(1)) % 4:
                problems.append((
                    number,
                    f"list item indented {len(marker.group(1))} spaces; Python-Markdown needs multiples of 4 to nest",
                ))
            if (
                TABLE_ROW.match(line)
                and previous.strip()
                and not TABLE_ROW.match(previous)
                and not HEADING.match(previous)
            ):
                problems.append((number, "table must be preceded by a blank line"))
            if GITHUB_ALERT.match(line):
                problems.append((number, "GitHub alert syntax renders as plain text; use a '!!! note' admonition"))
        previous = line
    return problems


# --- MkDocs events ---------------------------------------------------------------------------


def _location(page, config) -> str:
    """Repo-relative, forward-slash path of the page source, e.g. docs/ai-development/guide.md."""
    return f"{Path(config['docs_dir']).name}/{page.file.src_uri}"


def on_page_markdown(markdown, page, config, files):
    """Check 2 on the source file, so reported line numbers match the editor (frontmatter included)."""
    source = getattr(page.file, "content_string", None)  # MkDocs 1.6: BOM-safe, works for generated files
    if source is None:
        if not page.file.abs_src_path:
            return None
        source = Path(page.file.abs_src_path).read_text(encoding="utf-8-sig")
    for number, message in lint(source):
        log.warning("%s:%d: %s", _location(page, config), number, message)
    return None


def on_page_content(html_content, page, config, files):
    """Check 1: every URL in the page's markdown is a link (or image) in the rendered HTML."""
    for url in missing_links(page.markdown or "", html_content):
        log.warning("%s: URL is not a link in the rendered page: %s", _location(page, config), url)
    return None
