# vsa-agent-guardrails — experiment report

**Run:** (results folder name) · **Model:** (from the `model` column) · **Repetitions:** (n) · **Claude Code:** (version) · **Date:** (date)

## Setup

Two copies of the same orders API (`sliced/`, `layered/`), identical behaviour tests, five tasks (`experiment/tasks/`), each run in a fresh
temporary copy with `claude -p` (project settings only, `dontAsk`, tool allow-list; see the spec, section 5.2). Numbers below are medians
over the repetitions, with the range in parentheses.

## Results per task

| Task | Copy | files read | input tokens | cost USD | turns | files changed | out of scope | green runs |
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

"Green" = `build_ok` and no failed behaviour or architecture test. Duplication (`dup_blocks_after − dup_blocks_before`) and gate blocks
(`gate_blocks`) are reported per task below the table when non-zero.

## Hypotheses

- **H1** (slice-local tasks T1–T3: fewer files read, fewer input tokens, fewer out-of-scope edits in `sliced/`): supported / not supported / mixed — because …
- **H2** (T4 and T5: no advantage for `sliced/`): …
- **H3** (behaviour-test pass rate does not differ materially): …

## Caveats

Three repetitions; one model; one prompt per task; the layered copy is a well-structured layered app, not a big ball of mud;
the harness denies `cat`/`head`/`tail`/`sed` so file reads are countable, which changes agent behaviour slightly but equally for both copies.
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
On T3 the sliced rules steer the agent to duplicate the order summary in the new slice while the layered scope sanctions sharing
`OrderDtos.cs`, so a jscpd delta on T3 measures each architecture's sanctioned answer, not agent sloppiness. T3's scope globs
(`*Customer*`) accept any slice or query name containing "Customer"; an agent that instead adds a second route to the existing
`ListOrders` use case takes an out-of-scope hit in either copy — a naming judgement, not sprawl, so discount it when reading `files_out_of_scope`.
Wall time is not comparable across copies: the layered gate builds four projects per invocation, the sliced gate two.

## Raw data

`results/<folder>/results.csv`, with `events.jsonl`, `diff.patch`, `test-output.txt`, `gate.log` and `jscpd.json` per run.
