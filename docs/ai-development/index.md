---
title: AI development
---

# AI development

Building software with large language models at the centre, and building software *with* them: the control-flow primitives of agentic systems (agent loops and state graphs), the frameworks that implement them, what it takes to run them in production — evaluation, cost, human oversight, security, and memory — and how to structure a codebase so that coding agents work well in it. The scope is the engineering of agentic systems and of AI-assisted development, not model training.

**Status:** three guides, current as of September 2026.

## Guides

- [AI Development with Loops and Graphs](loops-and-graphs.md)

    A practical guide to control flow in agentic AI systems — how the loop and the graph became the two core primitives of AI development, when to use each, and how to build, secure, and operate them.

- [Vertical Slice Architecture for AI Development](vertical-slice-architecture.md)

    Why organising code by use case gives AI coding agents a bounded context, a bounded blast radius, and tests as back pressure — Jimmy Bogard's 2026 argument, what the evidence supports, where it breaks, and how to make the rules mechanical rather than cultural.

- [Generating Diagrams from a Codebase](generating-diagrams-from-code.md)

    Why the popular AI diagram skills do not read your code, what the three families of diagram tooling actually do, and how to publish an architecture diagram that stays true as the code moves.

## Prototypes

- [vsa-agent-guardrails](https://github.com/mortenbrudvik/dev-research/tree/main/prototypes/ai-development/vsa-agent-guardrails)

    The same orders API built twice — as vertical slices and as layers — with identical tests and the same guardrails, and a harness that gives Claude Code the same five tasks against each copy. 30 runs; the results are in [its report](https://github.com/mortenbrudvik/dev-research/blob/main/prototypes/ai-development/vsa-agent-guardrails/experiment/REPORT.md) and summarised in [section 10 of the guide](vertical-slice-architecture.md#10-applying-it-a-starter-checklist-and-a-prototype).
