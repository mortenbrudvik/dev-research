# vsa-agent-guardrails — experiment report

**Run:** (results folder name) · **Model:** (the `model` column: the primary model from the CLI's init event; `models_billed` lists every model billed) · **Repetitions:** (n) · **Claude Code:** (version) · **Date:** (date)

## Setup

Two copies of the same orders API (`sliced/`, `layered/`), identical behaviour tests, five tasks (`experiment/tasks/`), each run in a fresh
temporary copy with `claude -p` (project settings only, `dontAsk`, tool allow-list; see the spec, section 5.2). Numbers below are medians
over the repetitions, with the range in parentheses.

## Results per task

| Task | Copy | files read | context tokens | cost USD | turns | files changed | out of scope | green runs |
|---|---|---|---|---|---|---|---|---|
| T1 ship order | sliced | | | | | | | /n |
| T1 ship order | layered | | | | | | | /n |
| T2 no cancel after ship | sliced | | | | | | | /n |
| T2 no cancel after ship | layered | | | | | | | /n |
| T3 orders by customer | sliced | | | | | | | /n |
| T3 orders by customer | layered | | | | | | | /n |
| T4 audit trail | sliced | | | | | | | /n |
| T4 audit trail | layered | | | | | | | /n |
| T5 order notes | sliced | | | | | | | /n |
| T5 order notes | layered | | | | | | | /n |

`context tokens` = `cache_create_tokens`, the tokens newly written to the prompt cache — the closest measure of unique context the agent
ingested. `input_tokens` is only the uncached delta under prompt caching (30 tokens in a 27-turn smoke run) and cannot show a difference;
`cache_read_tokens` (context × turns) is quoted alongside where it tells a different story. "Green" = `build_ok` and no failed behaviour or architecture test. Duplication (`dup_blocks_after − dup_blocks_before`) and gate blocks
(`gate_blocks`) are reported per task below the table when non-zero.

## Hypotheses

- **H1** (slice-local tasks T1–T3: fewer files read, fewer context tokens, fewer out-of-scope edits in `sliced/`): supported / not supported / mixed — because …
- **H2** (T4 and T5: no advantage for `sliced/`): …
- **H3** (behaviour-test pass rate does not differ materially): …

## Caveats

Three repetitions — enough to see a direction, not to test significance; no statistical claim is made. One model; one prompt per task; the layered copy is a well-structured layered app, not a big ball of mud;
the harness denies `cat`/`head`/`tail`/`sed` so file reads are countable, and the `PowerShell` tool is not on the allow-list at all —
an agent on Windows reaches for both (the smoke run lost three turns to such denials); the friction is the same for both copies.
Limits of the architecture rules as an instrument: ArchUnitNET treats a sub-namespace inside a slice as a separate slice (the sliced
`CLAUDE.md` says so), and a slice rule passes vacuously when its pattern matches nothing (guarded by a presence test).
Gate blocks: `gate_blocks_build` are compile errors on a half-written change, not rule violations; only the remainder are guardrail catches.
The gate sees types and delegate signatures, not lambda bodies: a route delegate that resolves a forbidden type from `IServiceProvider`
inside its body passes the rules in both copies. `Program.cs` is invisible to ArchUnitNET (top-level statements) and is guarded only by
the `CompositionRoot` text test, which forbids the minimal-API `Map*` route registrations there; controller-, hub- and
middleware-registered routes are outside it (a controller would still be an `Orders.Api` type and subject to the rules).
Mechanical coverage of the likely wrong moves is asymmetric by design — the sliced rules fire on any cross-slice reuse and on shared code
under `Features/`, the layered rules only on Domain→up, Application→down and Api→persistence — and that asymmetry is part of what the
experiment measures. The layered copy's likeliest shortcut, querying through `IOrdersDbContext` from an endpoint, is caught by a rule
widened for fairness, not by the architecture.
Sanctioned duplication: a new slice copies the reference slice's handler and endpoint shape, so every task that adds a slice (T1, T3)
raises jscpd's clone count in the sliced copy (the smoke run's T1 went from 0 to 2 clones, 4.1 %) — read `dup_blocks_after - dup_blocks_before` as the
architecture's answer, not as sloppiness. On T3 the sliced rules additionally steer the agent to duplicate the order summary in the new
slice while the layered scope sanctions sharing `OrderDtos.cs`. T3's scope globs
(`*Customer*`) accept any slice or query name containing "Customer"; an agent that instead adds a second route to the existing
`ListOrders` use case takes an out-of-scope hit in either copy — a naming judgement, not sprawl, so discount it when reading `files_out_of_scope`.
Wall time is not comparable across copies: the layered gate builds four projects per invocation, the sliced gate two.
Token columns describe the primary model only (`result.usage`); `cost_usd` also includes the helper models the CLI bills alongside it
(`models_billed`). `--setting-sources project` does not gate MCP servers configured at user level: on this machine they were present but
unauthenticated and contributed no tools; where they are authenticated, their tools and tokens would enter every run of both copies.

## Raw data

`results/<folder>/results.csv`, with `events.jsonl`, `diff.patch`, `test-output.txt`, `gate.log` and `jscpd.json` per run.
