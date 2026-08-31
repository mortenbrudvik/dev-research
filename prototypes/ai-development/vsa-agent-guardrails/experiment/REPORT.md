# vsa-agent-guardrails — experiment report

**Run:** `results/20260831-132529` + `results/20260831-151205` · **Model:** `claude-opus-5[1m]` (billed alongside `claude-haiku-4-5`) · **Repetitions:** 3 · **Claude Code:** 2.1.251 · **Date:** 31 August 2026

## Setup

Two copies of the same orders API (`sliced/`, `layered/`), identical behaviour tests, five tasks (`experiment/tasks/`), each run in a fresh
temporary copy with `claude -p` (project settings only, `dontAsk`, tool allow-list; see the spec, section 5.2). Numbers below are medians
over the repetitions, with the range in parentheses.

30 runs completed: 5 tasks × 3 repetitions × 2 copies, run interleaved (task → repetition → copy) with the model pinned. Every one of the
30 finished green. Total spend for the completed runs was $29.44, plus $1.88 for one run lost to a rate limit and $5.49 for an earlier
four-run pilot of T4 and T5.

## Results per task

| Task | Copy | files read | context tokens | cost USD | turns | files changed | out of scope | green runs |
|---|---|---|---|---|---|---|---|---|
| T1 ship order | sliced | 13 | 29,700 (28,477–41,728) | 0.78 (0.65–0.86) | 29 (24–31) | 4 | 0 | 3/3 |
| T1 ship order | layered | 13 (11–15) | 30,354 (29,958–33,037) | 0.79 (0.75–0.82) | 29 (26–30) | 5 | 0 | 3/3 |
| T2 no cancel after ship | sliced | 10 (10–11) | 25,410 (24,074–26,137) | 0.65 (0.63–0.74) | 26 (24–28) | 4 (3–4) | 1 (0–1) | 3/3 |
| T2 no cancel after ship | layered | 11 (10–11) | 28,961 (28,162–29,551) | 0.80 (0.77–0.85) | 27 (25–28) | 4 | 1 | 3/3 |
| T3 orders by customer | sliced | 11 (11–12) | 28,055 (26,472–29,044) | 0.62 (0.57–0.71) | 23 (22–25) | 4 | 0 | 3/3 |
| T3 orders by customer | layered | 12 (12–14) | 28,388 (27,332–32,862) | 0.65 (0.63–0.71) | 25 (24–27) | 5 | 0 | 3/3 |
| T4 audit trail | sliced | 23 (22–24) | 55,099 (50,186–60,414) | 1.70 (1.63–1.88) | 49 (47–51) | 13 (12–13) | 0 | 3/3 |
| T4 audit trail | layered | 25 (25–26) | 59,453 (53,903–67,984) | 2.07 (1.55–2.26) | 58 (55–61) | 17 (17–19) | 0 (0–1) | 3/3 |
| T5 order notes | sliced | 15 (12–16) | 31,679 (29,181–34,858) | 0.87 (0.85–0.89) | 36 (35–37) | 13 | 0 | 3/3 |
| T5 order notes | layered | 14 (13–14) | 33,187 (32,297–33,224) | 0.92 (0.88–0.97) | 36 (34–36) | 13 | 0 | 3/3 |

`context tokens` = `cache_create_tokens`, the tokens newly written to the prompt cache — the closest measure of unique context the agent
ingested. `input_tokens` is only the uncached delta under prompt caching (30 tokens in a 27-turn smoke run) and cannot show a difference;
`cache_read_tokens` (context × turns) is quoted alongside where it tells a different story. "Green" = the run completed and `build_ok` with
no failed behaviour or architecture test. Duplication (`dup_blocks_after − dup_blocks_before`) and gate blocks
(`gate_blocks`) are reported per task below the table when non-zero.

**Cache reads**, the metric with the widest gap, being context re-read on every turn rather than ingested once
(sliced → layered, medians): T1 525k → 569k (+8 %), T2 477k → 611k (+28 %), T3 349k → 417k (+20 %),
T4 1.28M → 1.67M (+31 %), T5 671k → 695k (+3 %).

**Duplication.** T1 sliced +2 blocks, layered +3; T3 sliced 0, layered +1; T4 layered +1 in two of three runs; T2 and T5 zero in both.
This is the reverse of what the caveat below predicted — the sliced copy's mandated slice mirroring did not out-duplicate the layered copy
on any task.

**Gate blocks.** T1 layered 1 per run, T2 layered 1 per run, T4 sliced 0–3, T4 layered 4–6, T5 1 per run in both; sliced T1–T3 zero.
**30 of the 31 blocks were compile errors on a half-written change.** Exactly one was a real rule violation: `layered-T4-1` hit
`PostToolUse exit=2 tests/Orders.ArchitectureTests test` — a layering rule caught mid-task on the cross-cutting change — and the run
still finished green, so the agent recovered from it.

## Hypotheses

- **H1** (slice-local tasks T1–T3: fewer files read, fewer context tokens, fewer out-of-scope edits in `sliced/`): **partially supported.**
  Pooled over T1–T3 the sliced copy read fewer distinct files (11 vs 12), ingested fewer context tokens (28.1k vs 29.6k, +5 % for layered),
  re-read 24 % less context per run (458k vs 569k cache reads), took fewer turns (25 vs 27) and cost 19 % less ($0.65 vs $0.77). The
  direction is consistent across all three tasks on cost, cache reads and turns. The magnitudes are small — one file, 5 % of ingested
  context — and only cost and cache reads exceed 15 %. **The out-of-scope half of H1 is not supported at all:** both copies recorded zero
  out-of-scope edits on T1 and T3, and exactly one on T2 — the same file in both copies (the `Order` entity, which the agent chose to touch
  beyond the cancellation policy the globs anticipated). With guardrails in place, neither architecture produced sprawl.
- **H2** (T4 and T5: no advantage for `sliced/`): **not supported for T4, supported for T5.** The cross-cutting audit-trail task produced the
  *largest* gap in the experiment, all favouring the sliced copy: 22 % lower cost ($1.70 vs $2.07), 18 % fewer turns (49 vs 58), 31 % fewer
  files changed (13 vs 17) and 31 % fewer cache reads. The persistence task was a tie — layered read one file fewer, cost 6 % more, and both
  changed exactly 13 files. The prediction that slices lose their advantage on cross-cutting work is the one this experiment contradicts.
- **H3** (behaviour-test pass rate does not differ materially): **supported.** 30 of 30 runs green in both copies, with zero failing
  behaviour or architecture tests anywhere. Both copies added tests unprompted; T1 landed on exactly 18 passing tests in all six runs.

**The honest summary.** With a rules file, architecture tests and a blocking gate present in *both* copies, the architecture moved cost and
context by a consistent but modest margin, and moved correctness not at all. The cross-cutting task, not the slice-local ones, produced the
clearest separation. Nothing here supports a claim larger than "a real but small effect, in the predicted direction, on the quantities the
mechanisms predict" — and it is one model, one codebase, three repetitions.

## Caveats

Three repetitions — enough to see a direction, not to test significance; no statistical claim is made. One model; one prompt per task; the layered copy is a well-structured layered app, not a big ball of mud;
the harness denies `cat`/`head`/`tail`/`sed` so file reads are countable, and the `PowerShell` tool is not on the allow-list at all —
an agent on Windows reaches for both (81 denials across the 30 runs, a median of 3 per run, in both copies alike).
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
raises jscpd's clone count in the sliced copy — measured, this did not dominate: layered raised it more on both. On T3 the sliced rules
additionally steer the agent to duplicate the order summary in the new
slice while the layered scope sanctions sharing `OrderDtos.cs`. jscpd is run over `src` only, so duplication in test code — which per-use-case
tests produce in both copies — is never measured, and a clone block can be a run of `using` directives rather than logic.
Wall time is not comparable across copies: the layered gate builds four projects per invocation, the sliced gate two.
T3's layered scope admits any new file under `Endpoints/` while the sliced scope is name-gated (`*Customer*`); an agent that names its
endpoint file oddly is charged only in the sliced copy. Prompt-cache warmth is uncontrolled in `cache_create_tokens`: repetitions of the
same copy × task are spread out by the task → repetition → copy run order, but not guaranteed to fall outside the cache TTL.
T4's requirement that the trail cover "any operation added later" has no test that can fail, so a generic mechanism and two hard-coded writes
score identically; in the pilot both copies chose a generic mechanism, but the metric cannot distinguish them.
The hook's blocking output does not appear in `events.jsonl`, so a gate block's cost in turns and tokens cannot be audited from the artefacts,
only its occurrence from `.gate.log`.
Provider rate limits cost this experiment its first attempt at T4 and T5: 12 runs returned HTTP 429 with `terminal_reason: api_error`, and
one of them (`sliced-T4-1`, $1.88, 50 turns) was censored mid-flight rather than failing outright. All 12 were re-run to completion the same
day on the same model and CLI version, and the failed rows are excluded from every number above. Note for anyone reusing this harness: a
rate-limited run still reports `subtype: "success"`, so `ended` alone reads as a clean run — `is_error` and `terminal_reason` are the fields
that tell the truth, and a run where the agent never executed will otherwise score as "green" because the untouched tree builds and passes.

## Raw data

`experiment/results/20260831-132529/results.csv` (T1–T3, and the 12 rate-limited rows) and
`experiment/results/20260831-151205/results.csv` (the T4 and T5 re-runs), with `events.jsonl`, `diff.patch`, `test-output.txt`,
`gate.log`, `trx/` and `jscpd.json` kept per run. `pwsh experiment/Summarize-Results.ps1 -Path <csv>[,<csv>]` reproduces the table above;
it excludes failed runs from the medians and lists them separately.
