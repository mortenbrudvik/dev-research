# vsa-agent-guardrails

The minimal-pair experiment proposed in the guide
[Vertical Slice Architecture for AI Development](https://mortenbrudvik.github.io/dev-research/ai-development/vertical-slice-architecture/)
(section 10): the same small orders API built twice — `sliced/` as vertical slices with the guide's guardrails, `layered/` as
Domain / Application / Infrastructure / Api — with identical behaviour tests, and a harness that gives Claude Code the same five
tasks against each copy and records what it read, spent, changed and broke. Design: `docs/superpowers/specs/2026-08-26-vsa-agent-guardrails-design.md`
in the repository.

## What is in each copy

| | `sliced/` | `layered/` |
|---|---|---|
| Use cases | `src/Orders.Api/Features/{CreateOrder,CancelOrder,GetOrder,ListOrders}/` | `src/Orders.Application/Orders/{Commands,Queries}/…`, routes in `src/Orders.Api/Endpoints/OrdersEndpoints.cs` |
| Shared code | `Domain/`, `Platform/` | `Orders.Domain`, `Orders.Infrastructure` |
| Behaviour tests | `tests/Orders.SliceTests` | `tests/Orders.IntegrationTests` (same cases, file for file) |
| Architecture tests | slices independent; Domain and Platform never depend on Features | Domain depends on nothing; Application not on Infrastructure/Api; Api not on persistence |
| Agent guardrails | `CLAUDE.md`, `.claude/settings.json` + `.claude/hooks/gate.sh`, `.jscpd.json` | same, layer flavour |

## Build and test a copy

Requires the .NET SDK 10.0.100 or later. SQLite is embedded; no database server or Docker.

    cd sliced          # or layered
    dotnet build --nologo
    dotnet test --nologo                       # behaviour tests + architecture tests (+ negative controls)
    dotnet run --project src/Orders.Api        # http://localhost:5000, creates orders.db in the project folder

## Run the experiment

Requires PowerShell 7, Node 22 (`npx jscpd@4`), Git, Git Bash (the hooks are `sh` scripts), and Claude Code logged in.

    pwsh experiment/Test-ParseEvents.ps1                                  # the metrics library's tests, free
    pwsh experiment/Test-Parity.ps1                                       # both copies answer identically, free
    pwsh experiment/run.ps1 -Task T1 -Repetitions 1 -Yes -ClaudeCommand experiment/stub/claude.cmd   # the harness itself, free
    pwsh experiment/run.ps1 -Copy sliced -Task T1 -Repetitions 1          # smoke run, one paid agent run (~$2–8)
    pwsh experiment/run.ps1 -Yes                                          # both copies, five tasks, 3 repetitions (~$60–150)

Options: `-Copy sliced|layered|both`, `-Task T1[,T3]` (an unknown id fails before anything is copied or spent), `-Repetitions n`,
`-MaxBudgetUsd` (default 8; the per-run cap handed to `claude` itself), `-MaxTotalUsd` (default 200; stops the experiment as soon
as the rows add up past it), `-Model` (default: whatever the CLI picks — either way the `model` column records the ids the run
actually billed, taken from the transcript), `-ResultsDir`, `-KeepRuns` (leave the
temporary copies behind for inspection), `-Yes` (skip the typed confirmation — required for unattended runs of more than one
repetition) and `-ClaudeCommand` (which CLI to drive; `experiment/stub/claude.cmd` exercises the whole harness for nothing and is
how to check a change to `run.ps1` before paying for one).

Each run copies the variant to `%TEMP%\vsa-runs\`, gives Claude Code the task with project settings only (no user-level plugins or
hooks), an explicit tool allow-list and a budget cap, then builds, tests, diffs against the copy's baseline commit, runs jscpd, and
appends a row to `experiment/results/<timestamp>/results.csv` — one row per repetition, including for a repetition that failed
(`notes` then starts with `harness error:`). `experiment/results/example-results.csv` shows the columns; `experiment/REPORT.md`
is the template for writing the numbers up. Nothing in the repository is modified by a run; an interrupted run, and any run that
ended in a `harness error:`, leaves its copy under `%TEMP%\vsa-runs\` to be looked at, and it is safe to delete.

## Tasks

`experiment/tasks/`: T1 ship an order, T2 shipped orders cannot be cancelled, T3 list a customer's orders (slice-local);
T4 audit trail for every command (cross-cutting); T5 optional notes with a migration (persistence). Each file's front matter lists
the paths a correct solution is expected to touch in each copy; edits outside that list count as `files_out_of_scope`.
