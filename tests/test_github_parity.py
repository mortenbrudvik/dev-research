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

    def test_http_scheme(self):
        self.assertEqual(gp.find_urls("http://example.com/a"), ["http://example.com/a"])

    def test_trailing_period_stripped(self):
        self.assertEqual(gp.find_urls("Read https://example.com/a."), ["https://example.com/a"])

    def test_trailing_sentence_punctuation_stripped(self):
        for mark in ",;:!?":
            with self.subTest(mark=mark):
                self.assertEqual(gp.find_urls(f"See https://example.com/a{mark} then"), ["https://example.com/a"])

    def test_trailing_emphasis_delimiters_stripped(self):
        for wrapped in ("**https://example.com/a**", "*https://example.com/a*", "_https://example.com/a_", "~~https://example.com/a~~"):
            with self.subTest(wrapped=wrapped):
                self.assertEqual(gp.find_urls(wrapped), ["https://example.com/a"])

    def test_url_in_parentheses_in_prose(self):
        self.assertEqual(gp.find_urls("(see https://example.com/a)."), ["https://example.com/a"])

    def test_markdown_link_target(self):
        self.assertEqual(gp.find_urls("[docs](https://example.com/a) and more"), ["https://example.com/a"])

    def test_url_with_ampersand(self):
        self.assertEqual(gp.find_urls("https://example.com/?a=1&b=2"), ["https://example.com/?a=1&b=2"])

    def test_inline_code_skipped(self):
        self.assertEqual(gp.find_urls("run `curl https://example.com/a` now"), [])

    def test_double_backtick_code_span_skipped(self):
        self.assertEqual(gp.find_urls("run ``curl `-s` https://example.com/a`` now"), [])

    def test_fenced_block_skipped(self):
        text = "before\n```bash\ncurl https://example.com/a\n```\nafter https://example.com/b"
        self.assertEqual(gp.find_urls(text), ["https://example.com/b"])

    def test_tilde_fence_skipped(self):
        text = "~~~\nhttps://example.com/a\n~~~\nhttps://example.com/b"
        self.assertEqual(gp.find_urls(text), ["https://example.com/b"])

    def test_four_backtick_fence_wrapping_three_backtick_example(self):
        text = "````md\n```\nhttps://example.com/inner\n```\n````\nhttps://example.com/outer"
        self.assertEqual(gp.find_urls(text), ["https://example.com/outer"])

    def test_crlf_input(self):
        self.assertEqual(gp.find_urls("a https://example.com/a\r\n```\r\nhttps://example.com/b\r\n```\r\n"), ["https://example.com/a"])

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

    def test_image_src_counts_as_rendered(self):
        html = '<p><img alt="i" src="https://example.com/i.png" /></p>'
        self.assertEqual(gp.missing_links("![i](https://example.com/i.png)", html), [])

    def test_url_with_parentheses_matches_rendered_target_by_prefix(self):
        html = '<a href="https://en.wikipedia.org/wiki/Foo_(bar)">x</a>'
        self.assertEqual(gp.missing_links("<https://en.wikipedia.org/wiki/Foo_(bar)>", html), [])

    def test_mixed_linked_and_unlinked_keeps_order_and_duplicates(self):
        markdown = "https://example.com/a https://example.com/b https://example.com/a"
        html = '<a href="https://example.com/b">b</a>'
        self.assertEqual(gp.missing_links(markdown, html), ["https://example.com/a", "https://example.com/a"])


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

    def test_table_row_after_table_row_ok(self):
        self.assertEqual(gp.lint("\n| a | b |\n|---|---|\n| 1 | 2 |"), [])

    def test_table_as_first_line_ok(self):
        self.assertEqual(gp.lint("| a | b |\n|---|---|"), [])

    def test_table_after_heading_ok(self):
        self.assertEqual(gp.lint("## Heading\n| a | b |\n|---|---|"), [])

    def test_table_after_closing_fence_flagged(self):
        problems = gp.lint("```\ncode\n```\n| a | b |\n|---|---|")
        self.assertEqual([line for line, _ in problems], [4])

    def test_github_alert_flagged(self):
        problems = gp.lint("> [!NOTE]\n> text")
        self.assertEqual([line for line, _ in problems], [1])
        self.assertIn("admonition", problems[0][1])

    def test_lowercase_alert_flagged(self):
        self.assertEqual([line for line, _ in gp.lint("> [!tip]")], [1])

    def test_alert_without_space_and_nested_alert_flagged(self):
        self.assertEqual([line for line, _ in gp.lint(">[!NOTE]\n\n> > [!WARNING]")], [1, 3])

    def test_patterns_inside_fence_ignored(self):
        text = "```\n- a\n  - b\ntext\n| a |\n> [!NOTE]\n```"
        self.assertEqual(gp.lint(text), [])

    def test_tilde_fence_ignored(self):
        self.assertEqual(gp.lint("~~~\n- a\n  - b\n~~~"), [])

    def test_mixed_fence_markers_do_not_close_each_other(self):
        self.assertEqual(gp.lint("```\n~~~\n- a\n  - b\n```"), [])

    def test_four_backtick_fence_wrapping_three_backtick_example(self):
        self.assertEqual(gp.lint("````md\n```\n- a\n  - b\n```\n````"), [])

    def test_indented_fence_inside_list_item_ignored(self):
        self.assertEqual(gp.lint("- item\n\n    ```\n      - b\n    ```"), [])

    def test_frontmatter_yaml_list_ignored(self):
        text = "---\ntitle: x\ntags:\n  - ai\n---\n\n# Heading"
        self.assertEqual(gp.lint(text), [])

    def test_frontmatter_closed_with_dots_ignored(self):
        text = "---\ntags:\n  - ai\n...\n\n- a\n  - b"
        self.assertEqual([line for line, _ in gp.lint(text)], [7])

    def test_unclosed_frontmatter_does_not_disable_lint(self):
        text = "---\ntitle: x\n\n- a\n  - b"
        self.assertEqual([line for line, _ in gp.lint(text)], [5])

    def test_bom_before_frontmatter_ignored(self):
        text = "\ufeff---\ntitle: x\ntags:\n  - ai\n---\n"
        self.assertEqual(gp.lint(text), [])

    def test_horizontal_rule_mid_document_is_not_frontmatter(self):
        self.assertEqual([line for line, _ in gp.lint("# T\n\n---\n\n- a\n  - b")], [6])

    def test_crlf_line_numbers_match_editor(self):
        self.assertEqual([line for line, _ in gp.lint("- a\r\n  - b\r\n")], [2])

    def test_clean_document(self):
        text = "# Title\n\nSome text.\n\n| a | b |\n|---|---|\n\n- one\n    - two\n"
        self.assertEqual(gp.lint(text), [])


if __name__ == "__main__":
    unittest.main()
