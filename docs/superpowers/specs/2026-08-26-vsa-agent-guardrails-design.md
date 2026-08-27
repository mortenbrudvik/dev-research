# Prototype `vsa-agent-guardrails` — design

**Date:** 2026-08-26
**Status:** design approved in conversation (stack, harness, and the side-by-side layout were the owner's choices); awaiting owner review of this document before planning
**Scope:** the first prototype under `prototypes/ai-development/`: one small .NET 10 application built twice — once as vertical slices with the guardrails from the guide, once layered — plus a scripted harness that gives Claude Code the same tasks against each copy and records what it read, spent, changed and broke. It is the minimal-pair experiment that `docs/ai-development/vertical-slice-architecture.md` section 8.1 says nobody has published and section 10 proposes.

## 1. Purpose and hypothesis

The guide's thesis rests on mechanism arguments and experience reports; no study varies repository layout as the treatment and measures agent behaviour. This prototype does that at the smallest useful scale:

- **Treatment:** the same behaviour, the same HTTP contract, the same tests, in two layouts — `sliced/` (one folder per use case, guardrails from guide section 7) and `layered/` (Domain / Application / Infrastructure / Api, in the shape of Jason Taylor's Clean Architecture template, with its own equivalent guardrails).
- **Tasks:** five, identical prompts for both copies — three slice-local, one cross-cutting, one persistence change.
- **Measurements:** per run, what the agent read (distinct files, search calls), what it spent (tokens, cost, turns, wall time), what it changed (files and lines, and how many outside the task's expected scope), and what it broke (build, behaviour tests, architecture tests, duplication).

**Hypotheses** (from guide sections 5.1–5.3 and 8.2–8.3), stated so the results can contradict them:

- H1. On the three slice-local tasks, `sliced/` runs read fewer distinct files and use fewer input tokens than `layered/` runs, and make fewer edits outside the expected scope.
- H2. On the cross-cutting task (T4) and the persistence task (T5), `sliced/` shows no advantage; it may read more files and change more files than `layered/`.
- H3. Behaviour-test pass rate does not differ materially between the copies (as the SonarSource minimal-pair study found for code cleanliness); the differences are in cost and scope, not correctness.

Whatever the numbers say, they go into `experiment/REPORT.md` and, condensed, into the guide's section 8.1 and the topic's Prototypes list.

## 2. Decisions

| Question | Decision | Rejected alternatives |
|---|---|---|
| Stack | .NET 10 Minimal API, C#, EF Core with SQLite | TypeScript (Hono + Vitest) — less aligned with the guide's examples; both — doubles the work, revisit after first results |
| Database | SQLite through EF Core, one file per test class and per run | Testcontainers + PostgreSQL — no Docker on the development machine; EF in-memory provider — not relational, hides migration behaviour needed for T5 |
| Request handling | Plain endpoint → handler classes registered in DI; FluentValidation for request validation | MediatR — commercial licence since v13 and a dependency the experiment does not need; Wolverine/FastEndpoints — framework-specific shapes would make the two copies less comparable |
| How the two variants coexist | **A:** two self-contained copies side by side, `sliced/` and `layered/`, each its own solution and `CLAUDE.md` | B: one app, two branches — the agent can see the other layout in history, and the runner has to juggle branches; C: one solution, two projects — both layouts in the agent's context contaminates the comparison |
| Harness | Scripted headless runs: `claude -p` per task, one fresh copy of the variant per run, metrics parsed from `stream-json` output | Manual interactive sessions — operator-dependent, not repeatable |
| Runner language | PowerShell 7 (`experiment/run.ps1`) | Python — would depend on the site's `.venv` or a second toolchain; a .NET console runner — heavier than the job |
| Repetitions | 3 per copy × task by default (30 runs); `-Repetitions 1` for a smoke run | 1 — too noisy for a nondeterministic agent; 5+ — cost without a clear gain for a first experiment |
| Where a run executes | A fresh copy of the variant in a temporary directory outside the repository, initialised as its own git repository with one baseline commit | A git worktree of `dev-research` — the repository's root `CLAUDE.md` (site conventions) would be loaded into every run's context, and diffs would have to be scoped by path |
| Agent configuration per run | `--setting-sources project` (only the copy's `CLAUDE.md` and `.claude/settings.json`), `--permission-mode dontAsk`, an explicit tool allow-list plus a deny-list for content-dumping shell commands, the prompt piped on stdin | The machine's default settings — user-level plugins and hooks add ~50 tools and tens of thousands of cached tokens to every turn (measured 2026-08-26: 80 tools with user settings, 29 with project-only; a trivial run cost $0.54–0.87 versus $0.18); `--bare` — also skips `CLAUDE.md` discovery and hooks, which are the treatment |
| Bounding a run | `--max-budget-usd` per run | `--max-turns` — not present in Claude Code 2.1.246 |

## 3. Layout

```
prototypes/ai-development/vsa-agent-guardrails/
├── README.md                       what it demonstrates, how to build/test each copy, how to run the experiment, link to guide §10
├── .gitignore                      experiment/results/* (except example-results.csv) and the artefacts below at the prototype level
├── .gitattributes                  *.sh text eol=lf — this machine has core.autocrlf=true; a CRLF gate.sh fails every hook on a fresh clone
│   (each copy also carries its own .gitignore — bin/, obj/, *.db*, .gate.log, .jscpd-report/, .trx/ — because the runner copies the copy alone into a fresh git repository)
├── sliced/
│   ├── Orders.sln
│   ├── Directory.Build.props       net10.0, Nullable, ImplicitUsings, TreatWarningsAsErrors
│   ├── .config/dotnet-tools.json   dotnet-ef as a local tool
│   ├── CLAUDE.md                   guide §7.2 wording, adapted to this repo
│   ├── .claude/settings.json       PostToolUse (Edit|Write) and Stop hooks → gate.sh
│   ├── .claude/hooks/gate.sh       runs the architecture tests, then the slice tests; exit 2 with output on failure; appends one line per invocation (event, exit code) to .gate.log
│   ├── .jscpd.json                 csharp, src/, min-tokens 50, threshold 0, json + console reporters
│   ├── src/Orders.Api/
│   │   ├── Program.cs              builder, DbContext (SQLite), FluentValidation, endpoint discovery; `public partial class Program { }`
│   │   ├── Features/
│   │   │   ├── CreateOrder/        CreateOrderRequest, CreateOrderResponse, CreateOrderValidator, CreateOrderHandler, CreateOrderEndpoint
│   │   │   ├── CancelOrder/        CancelOrderRequest, CancelOrderResponse, CancelOrderHandler, CancelOrderEndpoint
│   │   │   ├── GetOrder/           GetOrderRequest, GetOrderResponse, GetOrderHandler, GetOrderEndpoint
│   │   │   └── ListOrders/         ListOrdersRequest, ListOrdersResponse, ListOrdersHandler, ListOrdersEndpoint
│   │   ├── Domain/                 Order, OrderLine, OrderStatus, CancellationPolicy
│   │   └── Platform/
│   │       ├── Persistence/        OrdersDbContext, entity configurations, Migrations/
│   │       ├── Endpoints/          IEndpoint (Map(IEndpointRouteBuilder)), MapEndpoints() discovery
│   │       └── Http/               validation endpoint filter, ProblemDetails mapping for domain errors
│   └── tests/
│       ├── Orders.SliceTests/      one test class per slice; WebApplicationFactory<Program>; fresh SQLite file per class
│       └── Orders.ArchitectureTests/  ArchUnitNET: slices do not depend on each other; slices depend only on Domain, Platform and frameworks; Domain depends on nothing in the app
├── layered/
│   ├── Orders.sln, Directory.Build.props, .config/dotnet-tools.json
│   ├── CLAUDE.md                   same commands and rules, expressed for layers (where commands, queries, endpoints, persistence live; Domain stays dependency-free)
│   ├── .claude/settings.json, .claude/hooks/gate.sh   same hooks, running this copy's test projects
│   ├── .jscpd.json
│   ├── src/Orders.Domain/          Entities/Order, Entities/OrderLine, Enums/OrderStatus, Policies/CancellationPolicy
│   ├── src/Orders.Application/     Common/Interfaces/IOrdersDbContext; Orders/Commands/CreateOrder/{Command, Validator, Handler}; Orders/Commands/CancelOrder/…; Orders/Queries/GetOrder/…; Orders/Queries/ListOrders/…; Orders/OrderDto
│   ├── src/Orders.Infrastructure/  Persistence/OrdersDbContext, Migrations/, DependencyInjection
│   ├── src/Orders.Api/             Endpoints/OrdersEndpoints.cs (all routes in one file), Program.cs
│   └── tests/
│       ├── Orders.IntegrationTests/   the same HTTP-level test cases as Orders.SliceTests, file for file
│       └── Orders.ArchitectureTests/  ArchUnitNET: Domain depends on nothing in the app; Application does not depend on Infrastructure or Api; Api does not depend on Infrastructure internals (or on IOrdersDbContext) except through DependencyInjection; a text test keeps Program.cs free of routes
└── experiment/
    ├── tasks/
    │   ├── T1-ship-order.md … T5-order-notes.md    front matter: id, title, expected scope per copy (glob lists); body: the prompt, identical for both copies
    ├── run.ps1                     the runner (section 5.2)
    ├── Parse-Events.ps1            stream-json → metrics, task-file parsing, scope globs, TRX and jscpd readers (dot-sourced by run.ps1)
    ├── Test-ParseEvents.ps1        plain-assertion tests for Parse-Events.ps1 against fixtures/ (no Pester dependency)
    ├── fixtures/                   sample-events.jsonl (observed 2.1.246 event shapes), sample-task.md
    ├── Test-Parity.ps1             starts both copies, sends the same requests, compares masked responses and the normalised text of the test classes (section 6)
    ├── results/
    │   ├── example-results.csv     committed: the columns, with one smoke-run row
    │   └── <timestamp>/            per experiment: results.csv, and per run events.jsonl, diff.patch, test-output.txt, jscpd.json
    └── REPORT.md                   template: setup, table per task, hypotheses H1–H3 with verdicts, caveats
```

Rules that follow:

- Nothing outside `docs/` is built by MkDocs, so the prototype cannot break the site; the guide and the topic index link to it with full GitHub URLs.
- The two copies share no code. Behavioural parity is enforced by keeping the test cases identical (section 4.4), not by sharing files.
- `experiment/results/` is gitignored except the committed example, so real runs never bloat the repository; `REPORT.md` carries the numbers.

## 4. The application

### 4.1 Domain and behaviour (identical in both copies)

A tiny orders service. `Order { Id: Guid, CustomerId: string, Lines: List<OrderLine>, Status: OrderStatus, CreatedAt, ShippedAt?, CancelledAt? }`, `OrderLine { Sku, Quantity, UnitPrice }`, `OrderStatus { Pending, Shipped, Cancelled }`. `Order.Ship()` and `Order.Cancel()` change status and timestamps and throw a domain exception on an invalid transition. `CancellationPolicy.CanCancel(order)` returns false only for already-cancelled orders in the baseline — deliberately permissive, so that task T2 ("shipped orders cannot be cancelled") is a real change. There is no `ShipOrder` use case in the baseline; `Order.Ship()` exists so tests and seed data can produce shipped orders, and task T1 exposes it.

Four use cases, four routes, identical request and response JSON in both copies:

| Use case | Route | Behaviour |
|---|---|---|
| CreateOrder | `POST /orders` | validates customer and at least one line with positive quantity and price; returns `201` with the id |
| CancelOrder | `POST /orders/{id}/cancel` | `404` unknown, `409` when `CancellationPolicy` says no, else `200` with the new status |
| GetOrder | `GET /orders/{id}` | `404` or `200` with the order |
| ListOrders | `GET /orders?status=` | optional status filter, newest first |

Validation failures return `400` ProblemDetails; domain-rule failures `409` ProblemDetails (`application/problem+json` on both paths). SQLite file per environment (`orders.db`), migrations applied at startup in Development and by the test fixtures. Timestamps are mapped with EF Core's `DateTimeOffsetToBinaryConverter` because SQLite stores `DateTimeOffset` as TEXT and EF Core refuses to order or compare it in SQL (found during implementation review, 2026-08-27).

### 4.2 Sliced copy

One folder per use case under `Features/`, five files each, no MediatR: the endpoint class implements `IEndpoint.Map` and calls the handler; the handler takes `OrdersDbContext` directly. `Domain/` holds entities and the policy; `Platform/` holds persistence, endpoint discovery, and the validation filter. No `Common/`, `Shared/` or `Helpers/`. The `CLAUDE.md` names `Features/CreateOrder/` as the reference slice.

### 4.3 Layered copy

Four projects. Handlers are the same classes moved into `Orders.Application` behind an `IOrdersDbContext` interface; all routes live in one `OrdersEndpoints.cs` in `Orders.Api`; persistence in `Orders.Infrastructure`. The `CLAUDE.md` names where each kind of code lives and points at `CreateOrder` as the reference command. This is the "forks in the fork drawer" shape the talk describes, done well — the comparison is layout, not quality.

### 4.4 Tests (both copies)

- **Behaviour tests** — HTTP in, HTTP and database out, through `WebApplicationFactory<Program>` with the SQLite connection string pointed at a fresh file per test class. The test cases are the same list in both copies (`CreateOrder_returns_201_and_persists`, `CancelOrder_of_cancelled_order_returns_409`, …); a run's "tests green" is therefore comparable across copies.
- **Architecture tests** — ArchUnitNET in both copies, enforcing each copy's own rule (section 3). Each suite includes a *negative control*: a test that loads a small fixture assembly containing a deliberate violation and asserts the rule fails on it, so a green architecture suite means the rule works, not that it matches nothing.
- **Framework versions** are whatever `dotnet new xunit` produces on SDK 10.0.100, with ArchUnitNET's matching adapter package; the plan pins the versions it finds.

### 4.5 Guardrails (both copies)

| Guardrail (guide section) | `sliced/` | `layered/` |
|---|---|---|
| Rules file (7.2) | `CLAUDE.md`: commands, slice rules, reference slices, "say so in your final message and keep it minimal" for edits under `Domain/`/`Platform/` (a literal stop-and-ask would abort a non-interactive `claude -p` run), never touch migrations | `CLAUDE.md`: commands, layer rules, reference commands, the same wording for `Orders.Domain`/`Orders.Infrastructure`, never touch migrations |
| Architecture test (7.1) | slices independent; slices → Domain/Platform/frameworks only (so no type directly under `Features/` and no `Common/`); Domain ↛ Features/Platform; Platform ↛ Features; plus a presence test so the slice pattern cannot pass vacuously. A slice is one flat namespace — ArchUnitNET counts a sub-namespace as another slice (stated in the sliced `CLAUDE.md`) | Domain → nothing; Application ↛ Infrastructure, Api; Api ↛ Infrastructure.Persistence and `IOrdersDbContext`; three negative controls. In both copies a `CompositionRoot` text test keeps `Program.cs` free of route registrations, because ArchUnitNET drops the `<Main>$` method and closure types that top-level statements compile into |
| Hooks (7.3) | PostToolUse (Edit/Write of a `.cs`/`.csproj`/`.props` file; other files are skipped) → `gate.sh` runs the architecture tests; Stop, or an event it cannot parse, → the architecture tests, then the behaviour tests (running the full suite after every edit would multiply run time and context). A block is logged as `build` when no test run happened (compile/analyzer/restore error on a half-written change) or `test` otherwise | same, this copy's projects |
| Duplication gate (7.6) | `.jscpd.json`, run by the harness, not by the hook (cost) | same |

Both copies get the same *kinds* of guardrail so that the treatment is the layout alone. The hooks require a POSIX shell on the machine that runs the agent (Git Bash on Windows). Verified on 2026-08-26 with Claude Code 2.1.246 on this machine: a `Stop` hook configured as `${CLAUDE_PROJECT_DIR}/.claude/hooks/gate.sh` runs in `-p` mode, exit code 2 blocks the stop, the agent receives the stderr text and continues, and the same holds under `--setting-sources project`. The hook writes its own `.gate.log` because the `stream-json` output does not reliably carry Stop-hook results (only a `system`/`notification` event with key `stop-hook-error`).

## 5. The experiment

### 5.1 Tasks

Each task file has front matter (`id`, `title`, `scope.sliced`, `scope.layered` — glob lists of the paths a correct, in-scope solution touches) and a body that is the prompt, identical for both copies. Prompts are written as a product owner would write a ticket: behaviour, acceptance criteria, "add tests", nothing about files.

| Id | Task | Kind | Expected scope (sliced / layered) |
|---|---|---|---|
| T1 | Ship an order: `POST /orders/{id}/ship`; `404` unknown, `409` if not pending, `200` with status; tests | slice-local, new use case | `Features/Ship*`, `Features/Ship*/**` + slice tests / `Application/Orders/Commands/Ship*`, `Application/Orders/Commands/Ship*/**`, `Application/DependencyInjection.cs`, `Application/Orders/OrderDtos.cs`, `Api/Endpoints/OrdersEndpoints.cs` + integration tests (the globs accept whatever name the agent gives the use case, as a folder or a single file) |
| T2 | Shipped orders can no longer be cancelled: `409` with a clear detail; tests | slice-local change | `Features/CancelOrder/**`, possibly `Domain/CancellationPolicy.cs` + tests / `Application/Orders/Commands/CancelOrder/**`, possibly `Domain/Policies/CancellationPolicy.cs` + tests |
| T3 | List a customer's orders: `GET /customers/{customerId}/orders`, newest first; tests | slice-local query | `Features/*Customer*`, `Features/*Customer*/**` + tests / `Application/Orders/Queries/*Customer*`, `Application/Orders/Queries/*Customer*/**`, `Application/DependencyInjection.cs`, `Application/Orders/OrderDtos.cs`, `Api/Endpoints/**`, `Api/Program.cs` (wiring the new `Map<Name>Endpoints()` call) + tests |
| T4 | Record an audit entry (who, what, when, order id) for every command; `GET /orders/{id}/audit` lists them; tests | cross-cutting | `Domain/**`, `Platform/**`, `Features/**`, `Program.cs` + tests / `Domain/**`, `Application/**`, `Infrastructure/**`, `Api/Common/**`, `Api/Endpoints/**`, `Api/Program.cs` + tests — both include the composition root and the HTTP-concerns folder, both exclude the API project file, settings and launch profiles |
| T5 | Add optional free-text `Notes` to an order, settable on create and returned on get; migration; tests | persistence | `Domain/Order.cs`, `Platform/Persistence/**` (migration), `Features/CreateOrder/**`, `Features/GetOrder/**` + tests / `Domain/Entities/Order.cs`, `Infrastructure/Persistence/**`, `Application/Orders/Commands/CreateOrder/**`, `Application/Orders/Queries/GetOrder/**`, `Application/Orders/OrderDtos.cs` + tests (no endpoint edit: `POST /orders` binds the command and `GET /orders/{id}` returns the DTO) |

T4 and T5 are *expected* to touch shared code; their scope lists say so. "Out-of-scope edits" is always measured against the task's own scope for that copy, and the raw files-changed count is reported alongside, so the reader can see both.

### 5.2 Runner (`experiment/run.ps1`)

Parameters: `-Copy sliced|layered|both` (default both), `-Task T1..T5|all` (default all), `-Repetitions <n>` (default 3), `-MaxBudgetUsd <n>` (default 8, per run), `-MaxTotalUsd <n>` (default 200; the runner stops once the running total exceeds it), `-Model <name>` (default: the CLI default), `-ResultsDir` (default `experiment/results/<yyyyMMdd-HHmmss>`), `-KeepRuns` (keep the temporary run directories), `-Yes` (skip the confirmation the runner asks for before more than one paid run), `-ClaudeCommand <path>` (default `claude`; point it at `experiment/stub/claude.cmd` to exercise the harness without paying).

Per run (copy × task × repetition):

1. **Fresh copy.** Copy the variant folder (excluding `bin/`, `obj/`, `.jscpd-report/`, `.trx/`, `.claude/worktrees/`, `*.db*` and `.gate.log`) to a temporary directory outside the repository (`$env:TEMP\vsa-runs\<copy>-<task>-<n>\`); `git init`, commit everything as the baseline. The copy's `CLAUDE.md` and `.claude/` come with it; the repository root's `CLAUDE.md` does not.
2. **Baseline build and test** once per copy per experiment (not per run) to confirm the starting state is green; abort the experiment if it is not.
3. **Agent run.** In that directory, exactly:

    ```
    claude -p --output-format stream-json --verbose --no-session-persistence
           --setting-sources project --permission-mode dontAsk
           --allowedTools "Read,Glob,Grep,Edit,Write,Bash(dotnet *),Bash(git *)"
           --disallowedTools "Bash(cat *),Bash(head *),Bash(tail *),Bash(sed *),Bash(type *)"
           --max-budget-usd <n> [--model <name>] < prompt.md > events.jsonl 2> stderr.txt
    ```

    `dontAsk` denies tools outside the allow-list without prompting, but it still permits built-in read-only shell commands — measured on 2026-08-26: `ls` and `cat` ran with only `Read` allowed — so the content-dumping commands are denied explicitly, which forces file contents through `Read` where the runner can count them (the `PowerShell` tool is likewise absent from the allow-list, so a PowerShell pipeline is denied too — the smoke run lost three turns to such denials, and the friction is identical for both copies); `ls`, `dir`, `find` and `grep` through Bash are counted as search calls. The prompt is piped on stdin from `prompt.md`, which is kept with the run's artefacts so a run is reproducible; the closed stdin also avoids the CLI's 3-second wait for piped input. Wall time is measured by the runner. Event field names are those observed for 2.1.246 (section 5.3); if the CLI changes, `Parse-Events.ps1` is the one file to update.
4. **After the run,** in the same directory: `dotnet build` (warnings as errors), `dotnet test` per test project with results captured, `git add -A` followed by `git diff --cached --no-renames --name-only` and `--numstat` against the baseline commit (so an agent that commits is still measured; a moved file counts as two), `git diff --cached --no-renames <baseline> > diff.patch`, `npx jscpd@4 src` (JSON reporter; the path is positional because jscpd's config `path` is a no-op on Windows) before (cached per copy) and after. The hooks in the copy's `.claude/settings.json` run as OS processes outside the permission system, so the tool allow-list does not constrain them — deliberate: the gate is part of the treatment.
5. **Record** one row in `results.csv`, keep the per-run artefacts, delete the temporary directory unless `-KeepRuns`.

The runner never edits the copies in the repository; a failed or interrupted run leaves nothing behind except its temporary directory.

### 5.3 Metrics (one CSV row per run)

| Column | Source |
|---|---|
| `copy, task, rep, model, started_at` | runner |
| `cost_usd, num_turns, duration_ms, duration_api_ms, input_tokens, output_tokens, cache_read_tokens, cache_create_tokens` | the final `result` event of `stream-json`: `total_cost_usd`, `num_turns`, `duration_ms`, `duration_api_ms`, `usage.input_tokens`, `usage.output_tokens`, `usage.cache_read_input_tokens`, `usage.cache_creation_input_tokens` (observed on 2.1.246; `modelUsage` is kept in the per-run JSON) |
| `ended, terminal_reason, is_error, permission_denials` | result event `subtype` (e.g. `success`), `terminal_reason` and `stop_reason` recorded verbatim, `is_error`, and the length of its `permission_denials` array — a budget stop shows up here and in `notes` |
| `files_read_distinct, read_calls, grep_calls, glob_calls, edit_calls, write_calls, bash_calls, bash_search_calls` | `assistant` events, `message.content[]` blocks with `type == "tool_use"`, by `name`; `Read` → `input.file_path` deduplicated; `Bash` → `input.command`, counted as a search call when it starts with `ls`, `dir`, `find`, `grep`, `rg` or `git grep` |
| `gate_blocks, gate_blocks_build` | lines with exit code 2 in the run directory's `.gate.log`, written by `gate.sh`; the `build` subset are compile errors on a half-written change (not rule violations), so guardrail catches are the difference |
| `files_changed, lines_added, lines_deleted` | after `git add -A`: `git -c core.quotepath=false diff --cached --name-only` and `git diff --cached --numstat` against the baseline commit |
| `files_out_of_scope` | changed paths not matching the task's scope globs for this copy |
| `build_ok, behaviour_tests_passed, behaviour_tests_failed, arch_tests_passed, arch_tests_failed` | `dotnet build` / `dotnet test` exit codes and TRX summaries |
| `dup_blocks_before, dup_blocks_after, dup_lines_pct_after` | jscpd JSON |
| `notes` | runner: e.g. `ended=error_max_budget_usd`, `no result event`, `claude exit 1`, `N permission denials`, `agent committed (N commits)`, `no behaviour trx (build failed?)`, `harness error: …` |

`REPORT.md` aggregates per copy × task: median and range of `files_read_distinct`, `input_tokens`, `cost_usd`, `files_changed`, `files_out_of_scope`, and the fraction of runs with `build_ok && behaviour_tests_failed == 0 && arch_tests_failed == 0`.

### 5.4 Cost

Measured baseline on 2026-08-26 with the CLI's default model (Claude Fable 5): a trivial five-turn run with project-only settings cost `$0.18` and carried about 27k cached tokens per turn; the same kind of run with the machine's user-level settings cost `$0.54–0.87`. A real task run of 20–40 turns was therefore expected to cost `$2–8`, and `-MaxBudgetUsd` defaults to `8` as a ceiling; the first real run (2026-08-27, sliced, T1: 27 turns, 14 files read, 581k cached tokens) cost `$0.72`, so a full 30-run experiment is likely to land nearer `$20–40`. Default experiment: 2 copies × 5 tasks × 3 repetitions = 30 runs — hard ceiling `$240`, expected `$60–150`. `-Repetitions 1 -Task T1` is the smoke run that calibrates the budget before a full experiment; `-Model claude-sonnet-5` cuts the cost several-fold if the owner prefers to run the bulk of the repetitions on a cheaper model (then the model is a recorded column, and the report compares like with like). The runner prints the running total after each run.

## 6. Verification

- Each copy: `dotnet build` clean with warnings as errors; `dotnet test` green for both test projects; the architecture suite's negative control fails on the deliberate violation and passes on the real code.
- Behavioural parity: the same test file list in `Orders.SliceTests` and `Orders.IntegrationTests`, and an HTTP-level parity check in the plan (run both copies, hit the four routes with the same requests, diff the JSON).
- Hooks: after an `Edit` in an interactive Claude Code session inside `sliced/`, `gate.sh` runs and its failure text reaches the agent; a `Stop` with a failing test is blocked and `.gate.log` records it. (The mechanism was verified with a simulated gate on 2026-08-26; this re-checks it with the real test projects.)
- Harness: `run.ps1 -Copy sliced -Task T1 -Repetitions 1` completes, writes one CSV row with every column filled, and leaves the repository working tree unchanged (`git status` clean apart from `results/`); `Parse-Events.ps1` reproduces the row from the saved `events.jsonl`.
- Site: `mkdocs build --strict` unaffected (the prototype is outside `docs/`); the guide's section 10 and the topic index link to the prototype's GitHub URL once it exists.
- Clean clone: the README's commands work from a fresh checkout on a machine with SDK 10, Node 22 (for `npx jscpd`), Claude Code and Git Bash.

## 7. Documentation

- `prototypes/ai-development/vsa-agent-guardrails/README.md`: what it demonstrates, the two layouts, how to build and test each, how to run the experiment and read the report, the guide section it illustrates.
- After the first full experiment: `experiment/REPORT.md` filled in; guide section 8.1 gains a paragraph with the headline numbers and a link; section 10's "Not started" becomes a link; `docs/ai-development/index.md` lists the prototype under Prototypes. Those doc edits are a separate change after results exist, not part of building the prototype.

## 8. Out of scope

- A TypeScript mirror; PostgreSQL/Testcontainers; MediatR, Wolverine or FastEndpoints variants.
- Comparing models, prompts or permission modes — one model, one prompt per task.
- Any automation that edits the copies in place (a "dedup routine") — the harness only measures.
- Statistical claims beyond medians and ranges over three repetitions; the report says so.
