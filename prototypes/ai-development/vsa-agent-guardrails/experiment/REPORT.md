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

**Out-of-scope edits, and what they were.** Six of the 30 runs touched a file outside their task's scope globs, and the six are three
unlike things. Five are T2's `Order` entity — all three layered runs and two of three sliced (`sliced-T2-2` is the exception, and is the
existence proof that the task is completable within the globs: three files, all in scope, green, and it says why it stopped —
"so the shipped rule lives in one place rather than being duplicated in the entity"). Of those five, three (`sliced-T2-1`, `sliced-T2-3`,
`layered-T2-3`) inserted a second `Status == Shipped` throw beside the existing one, leaving the same user-facing sentence in two files;
two (`layered-T2-1`, `layered-T2-2`) added no guard at all but rewired the existing one to call the policy that already depends on `Order`
— a de-duplicating refactor, the opposite move. None of the five throws can fire: the handler consults the policy first, and `ApiFixture`
reaches `Cancel` only from `Pending`. All five announced the `Domain/` edit in their final message, as both copies' `CLAUDE.md` require.

The sixth is the opposite kind of edit. `layered-T4-1` changed `tests/Orders.ArchitectureTests/LayerRules.cs`, which T4's `scope.layered`
does not list — the only test glob it names is `tests/Orders.IntegrationTests/**` — adding `Every_command_handler_writes_to_the_audit_trail`
plus a companion test pinning that rule's own patterns to the two real handlers, taking the layered suite from 9 rules to 11. It is the
most direct answer any run gave to the prompt's "and any operation added later", and the only run of the 30 to touch an architecture test
or a `CLAUDE.md` at all.

**So `files_out_of_scope` counts path matches, not defects.** The same value of 1 marks a duplicated guard, a de-duplicating refactor and
a strengthened guardrail; the file has to be read before the number means anything.

**Gate blocks.** T1 layered 1 per run, T2 layered 1 per run, T4 sliced 0–3, T4 layered 4–6, T5 1 per run in both; sliced T1–T3 and
layered T3 zero — 31 in total, **24 of them in the layered arm against 7 in the sliced one**, the same "more places to touch" effect the
T4 section below describes. 30 were build-stage failures, where the tests never ran: the hook labels a block `build` when its output
never reaches `Test run for`, so the bucket covers restore, MSBuild and analyzer failures, not only compiler diagnostics. Nearly all are
the same shape — a declaration and its use, or a statement and its `using`, landing in two separate edits. Both copies set
`TreatWarningsAsErrors`, so an unused `using` or an unread constructor parameter is itself a build error and *neither order* of a two-edit
change avoids a block; `layered-T4-3` said so mid-run ("Expected mid-change build errors — continuing"). The counts track how many edits a
change needed, not how carelessly it was made.

Exactly one block was a rule violation, and it was deliberate. In `layered-T4-1`, with both suites already green, the agent removed the
`AuditTrail` dependency from `CancelOrderCommandHandler` to check that an architecture rule *it had itself added* 40 seconds earlier could
fail — first the `audit.Record(...)` call (which the compiler caught instead: `CS9113: Parameter 'audit' is unread`), then the constructor
parameter, which fired `Every_command_handler_writes_to_the_audit_trail` (`PostToolUse exit=2 tests/Orders.ArchitectureTests test`,
13:23:08). It restored both and the gate was green again at 13:23:20. Two of the 30 build blocks belong to that same episode, so **28 of
the 31 were unintended**. No gate block in the 30 runs was an unintended violation of an architecture rule, and none involved a rule that
shipped with either copy. The hook's stderr reaches no run's `events.jsonl` — a blocked edit's tool result is the ordinary success string
with no diagnostic attached — so what the agent was shown is not in the artefacts; only what it did next, plus its own paraphrase in
several runs.

## Why T4 separated the copies

The 13-vs-17 median decomposes, and most of it cancels. Every one of the six T4 diffs carries the same three generated EF migration files
(191 added lines), produced by one `dotnet ef migrations add` and hand-edited in no run, and one new test file. Netting out migrations,
tests and docs leaves authored production files: sliced 9 / 9 / 8, layered 13 / 13 / 13.

The four-file difference is the *same four files* in all three layered runs, and none appears in any sliced run:

1. `Orders.Application/Common/Interfaces/ICurrentUser.cs` (`ICurrentActor.cs` in reps 2–3) — an actor port.
2. `Orders.Api/Common/HeaderCurrentUser.cs` (`HttpCurrentActor.cs`) — the API-side adapter that reads `X-User`.
3. `Orders.Application/Common/Interfaces/IOrdersDbContext.cs` — one line, declaring the audit `DbSet` a second time, because handlers see
   the context only through the abstraction.
4. `Orders.Application/DependencyInjection.cs` — the second composition point, since the Application module cannot name an API type.

Files 1 and 2 exist because `Orders.Application.csproj` references only `Orders.Domain`, so `IHttpContextAccessor` is unreachable from where
the recorder lives; the sliced copy is allowed to put HTTP concerns in `Platform/`, so the port/adapter pair collapses into one 20-line
class. On the read side the arms trade evenly — layered appends to the shared `OrderDtos.cs` and `OrdersEndpoints.cs`, sliced adds two new
files inside its new slice.

Two deflations belong with that headline. **File count is not code volume:** authored production lines run sliced 125 / 182 / 195 against
layered 149 / 136 / 135, so the sliced copy wrote *more* production code in two of three runs, and total added lines are a wash. What T4
shows is that the same feature needed four more *places* in the layered copy, not more work. **And only turns separate the arms run by
run** (layered 55–61 vs sliced 47–51): cost and cache reads separate them on medians only, because `layered-T4-2` built the same thirteen
places for $1.55 and 1.04M cache reads — less than any sliced run.

Mechanism does not explain the gap, and the runs disagree about mechanism: `sliced-T4-2` and `sliced-T4-3` used an EF `SaveChanges`
interceptor and edited no existing use case, while the other four wrote explicit `audit.Record(...)` calls into both handlers.
`sliced-T4-1` and `layered-T4-1` chose the *same* mechanism and still differ 9 versus 13 production files, which is the cleanest comparison
in the set. A fourth sliced attempt (`results/20260831-132529/sliced-T4-1`, an interceptor, 13 files, in scope, no gate blocks) was cut off
by the rate limit and is excluded — an exclusion that trims only the sliced arm, since no layered attempt was lost after doing real work.

## Hypotheses

- **H1** (slice-local tasks T1–T3: fewer files read, fewer context tokens, fewer out-of-scope edits in `sliced/`): **partially supported.**
  Pooled over T1–T3 the sliced copy read fewer distinct files (11 vs 12), ingested fewer context tokens (28.1k vs 29.6k, +5 % for layered),
  re-read 24 % less context per run (458k vs 569k cache reads), took fewer turns (25 vs 27) and cost 19 % less ($0.65 vs $0.77). The
  direction is consistent across all three tasks on cost, cache reads and turns. The magnitudes are small — one file, 5 % of ingested
  context — and only cost and cache reads exceed 15 %. **The out-of-scope half of H1 is not supported at all:** both copies recorded zero
  out-of-scope edits on T1 and T3, and one on five of the six T2 runs — the `Order` entity in both copies, which the agent chose to touch
  beyond the cancellation policy the globs anticipated, and which the out-of-scope paragraph above shows is not a single kind of edit.
  With guardrails in place, neither architecture produced sprawl.
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
only its occurrence from `.gate.log` and, in several runs, the agent's own paraphrase of what it was told.
The six T2 and six T4 diffs were read closely; the other 18 were spot-checked, so no exhaustive defect audit stands behind any claim here.
One latent defect was found, and it is in in-scope code on both sides of the comparison: `layered-T2-1` leaves `CanCancel` and its refusal
reason as independent expressions, so a fourth `OrderStatus` would yield a null conflict and a 200 with a null body, while `sliced-T2-2`
and `sliced-T2-3` write the policy as a deny-list, so a fourth status would become cancellable rather than refused.
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
