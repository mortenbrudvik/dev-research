#requires -Version 7
<#
.SYNOPSIS
  Runs Claude Code headlessly against the sliced and layered copies on the experiment tasks and records metrics.
.DESCRIPTION
  Per copy x task x repetition: copies the variant to %TEMP%\vsa-runs\<name>, makes it a git repo with one baseline commit,
  runs `claude -p` with the prompt on stdin (spec 5.2), then builds, tests, diffs against that baseline commit, runs jscpd,
  and appends one CSV row. Every repetition writes exactly one row: an unexpected failure becomes a row whose notes start
  with "harness error", and the experiment carries on.
.EXAMPLE
  pwsh experiment/run.ps1 -Copy sliced -Task T1 -Repetitions 1        # smoke run, one paid agent run
  pwsh experiment/run.ps1 -Yes                                        # full experiment: both copies, all tasks, 3 reps
  pwsh experiment/run.ps1 -Task T1 -Repetitions 1 -Yes -ClaudeCommand experiment/stub/claude.cmd   # harness test, free
#>
[CmdletBinding()]
param(
    [ValidateSet('sliced', 'layered', 'both')] [string]$Copy = 'both',
    [string[]]$Task = @('all'),
    [int]$Repetitions = 3,
    [double]$MaxBudgetUsd = 8,
    [double]$MaxTotalUsd = 200,
    [string]$Model,
    [string]$ClaudeCommand = 'claude',
    [string]$ResultsDir,
    [switch]$KeepRuns,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[cultureinfo]::CurrentCulture = [cultureinfo]::InvariantCulture   # "-MaxBudgetUsd 2,5" and CSV decimals must not follow a comma culture

. "$PSScriptRoot/Parse-Events.ps1"

$root = Split-Path -Path $PSScriptRoot -Parent
$claudeCmd = Get-Command -Name $ClaudeCommand -ErrorAction SilentlyContinue
# An alias or a function is not a process to pipe a prompt into and to read an exit code from, so it is rejected here
# rather than half-working later.
if (-not $claudeCmd -or $claudeCmd.CommandType -notin @('Application', 'ExternalScript') -or -not $claudeCmd.Source) {
    throw "-ClaudeCommand '$ClaudeCommand' is neither on PATH nor a path to a command"
}
$claude = (Resolve-Path -LiteralPath $claudeCmd.Source).Path      # absolute: the CLI is invoked after Push-Location
$copies = if ($Copy -eq 'both') { @('sliced', 'layered') } else { @($Copy) }
$taskFiles = @(Get-ChildItem -Path "$PSScriptRoot/tasks" -Filter 'T*.md' | Sort-Object Name)
$knownIds = @($taskFiles | ForEach-Object { ($_.BaseName -split '-')[0] })
$Task = @($Task -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })   # `pwsh run.ps1 -Task T1,T2` arrives as one string
if ($Task -notcontains 'all') {
    # A typo must not silently shrink the experiment: -Task T1,T9 fails here, before anything is copied or spent.
    $unknown = @($Task | Where-Object { $knownIds -notcontains $_ })
    if ($unknown.Count -gt 0) { throw "Unknown task id(s): $($unknown -join ', '). Known ids: $($knownIds -join ', '), or 'all'." }
    $taskFiles = @($taskFiles | Where-Object { $Task -contains ($_.BaseName -split '-')[0] })
}
if ($taskFiles.Count -eq 0) { throw "No task files match -Task $($Task -join ',')" }

$plannedRuns = $copies.Count * $taskFiles.Count * $Repetitions
if ($plannedRuns -gt 1 -and -not $Yes) {
    Write-Host ("About to make {0} agent runs: worst case `${1:N2} at -MaxBudgetUsd `${2:N2} each, capped at -MaxTotalUsd `${3:N2}." -f
        $plannedRuns, ($plannedRuns * $MaxBudgetUsd), $MaxBudgetUsd, $MaxTotalUsd)
    if ((Read-Host 'Proceed? Type y to continue') -ne 'y') { throw 'Cancelled; nothing was run. Pass -Yes for unattended runs.' }
}

if (-not $ResultsDir) { $ResultsDir = Join-Path $PSScriptRoot "results/$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
$ResultsDir = (Resolve-Path -LiteralPath $ResultsDir).Path        # a relative -ResultsDir must survive Push-Location
$csv = Join-Path $ResultsDir 'results.csv'
$runsRoot = Join-Path $env:TEMP 'vsa-runs'
$behaviourProject = @{ sliced = 'tests/Orders.SliceTests'; layered = 'tests/Orders.IntegrationTests' }
$archProject = 'tests/Orders.ArchitectureTests'
$git = @('-c', 'user.name=runner', '-c', 'user.email=runner@example.invalid')

function New-ResultRow([hashtable]$values) {
    # One fixed column set for every row. Export-Csv -Append rejects an object whose properties differ from the
    # header, so a harness-error row must carry the same columns, in the same order, with the rest left empty.
    $names = @(
            'copy', 'task', 'rep', 'model', 'models_billed', 'started_at', 'wall_ms',
            'cost_usd', 'num_turns', 'duration_ms', 'duration_api_ms',
            'input_tokens', 'output_tokens', 'cache_read_tokens', 'cache_create_tokens',
            'ended', 'terminal_reason', 'stop_reason', 'is_error', 'permission_denials', 'skipped_lines',
            'files_read_distinct', 'read_calls', 'grep_calls', 'glob_calls',
            'edit_calls', 'write_calls', 'bash_calls', 'bash_search_calls',
            'gate_blocks', 'gate_blocks_build',
            'files_changed', 'lines_added', 'lines_deleted', 'files_out_of_scope', 'build_ok',
            'behaviour_tests_passed', 'behaviour_tests_failed', 'arch_tests_passed', 'arch_tests_failed',
            'dup_blocks_before', 'dup_blocks_after', 'dup_lines_pct_after', 'notes')
    # A mistyped key would otherwise leave its column silently empty in every row.
    $unknown = @($values.Keys | Where-Object { $names -notcontains $_ })
    if ($unknown) { throw "New-ResultRow: unknown column(s) $($unknown -join ', ')" }
    $row = [ordered]@{}
    foreach ($name in $names) { $row[$name] = if ($values.ContainsKey($name)) { $values[$name] } else { '' } }
    return [pscustomobject]$row
}

function Format-Metric($value, [string]$format = '{0}') {
    # A missing number is not a zero: an interrupted run must not print "cost $0.00" or "behaviour 0/0".
    if ($null -eq $value) { return 'n/a' }
    return ($format -f $value)
}

function New-RunDirectory([string]$copyName, [string]$runName) {
    $src = Join-Path $root $copyName
    $dst = Join-Path $runsRoot $runName
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    # Claude Code keeps per-project memory under %USERPROFILE%\.claude\projects\<sanitised working directory>,
    # and this run directory's name is deterministic, so without this every rep 1 would start with the memory
    # the last experiment's rep 1 left behind - a treatment nobody asked for.
    $memoryRoot = Join-Path $env:USERPROFILE '.claude/projects'
    if (Test-Path $memoryRoot) {
        foreach ($stale in @(Get-ChildItem -Path $memoryRoot -Directory -Filter "*-vsa-runs-$runName" -ErrorAction SilentlyContinue)) {
            Remove-Item -Recurse -Force $stale.FullName
            Write-Host "stale agent memory removed: $($stale.FullName)"
        }
    }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    & robocopy $src $dst /E /XD bin obj worktrees .jscpd-report .trx /XF *.db *.db-shm *.db-wal .gate.log /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $src -> $dst failed with exit code $LASTEXITCODE" }
    Push-Location $dst
    try {
        & dotnet tool restore 2>&1 | Out-Null          # makes `dotnet ef` available in the fresh copy (local tool manifest)
        & dotnet ef --version 2>&1 | Out-Null          # `tool restore` exits 0 with no manifest, so probe the capability itself
        if ($LASTEXITCODE -ne 0) { throw "dotnet ef is unavailable in $dst - dotnet tool restore did not succeed" }
        & git init -q
        & git @git add -A 2>&1 | Out-Null              # discards the autocrlf "LF will be replaced by CRLF" warnings
        if ($LASTEXITCODE -ne 0) { throw "git add -A failed in $dst" }
        & git @git commit -q -m 'baseline'
        if ($LASTEXITCODE -ne 0) { throw "baseline commit failed in $dst" }
        $baseSha = (& git rev-parse HEAD).Trim()
    }
    finally { Pop-Location }
    return [pscustomobject]@{ dir = $dst; baseSha = $baseSha }
}

function Invoke-DotnetTest([string]$dir, [string]$project, [string]$trxName) {
    Push-Location $dir
    try {
        $out = & dotnet test $project --nologo -v q --logger "console;verbosity=normal" --logger "trx;LogFileName=$trxName" --results-directory (Join-Path $dir '.trx') 2>&1
        return [pscustomobject]@{ ok = ($LASTEXITCODE -eq 0); output = (@($out) -join "`n"); trx = (Join-Path $dir ".trx/$trxName") }
    }
    finally { Pop-Location }
}

function Invoke-Jscpd([string]$dir) {
    Push-Location $dir
    try {
        Remove-Item -Recurse -Force (Join-Path $dir '.jscpd-report') -ErrorAction SilentlyContinue   # never read a stale report
        & npx -y jscpd@4 src --config .jscpd.json --silent 2>&1 | Out-Null   # positional path: the config's "path" is a no-op on Windows
    }
    finally { Pop-Location }
    return Read-JscpdSummary -Path (Join-Path $dir '.jscpd-report/jscpd-report.json')
}

function Invoke-Agent([string]$dir, [string]$promptFile, [string]$eventsFile, [string]$stderrFile) {
    $cliArgs = @(
        '-p', '--output-format', 'stream-json', '--verbose', '--no-session-persistence',
        '--setting-sources', 'project', '--permission-mode', 'dontAsk',
        '--allowedTools', 'Read,Glob,Grep,Edit,Write,Bash(dotnet *),Bash(git *)',
        '--disallowedTools', 'Bash(cat *),Bash(head *),Bash(tail *),Bash(sed *),Bash(type *),Bash(git show *),Bash(git cat-file *)',
        '--max-budget-usd', "$MaxBudgetUsd"
    )
    if ($Model) { $cliArgs += @('--model', $Model) }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Push-Location $dir
    try {
        Get-Content -Path $promptFile -Raw | & $claude @cliArgs 2> $stderrFile | Set-Content -Path $eventsFile -Encoding utf8
        $exit = $LASTEXITCODE
    }
    finally { Pop-Location }
    $sw.Stop()
    return [pscustomobject]@{ exit = $exit; wall_ms = $sw.ElapsedMilliseconds }
}

$runningTotal = 0.0
$firstModel = $null
$dupBefore = @{}
$dupBeforeJson = @{}
try {
    foreach ($copyName in $copies) {
        Write-Host "== baseline check: $copyName"
        $baseRun = New-RunDirectory $copyName "$copyName-baseline"
        $base = $baseRun.dir
        $archBase = Invoke-DotnetTest $base $archProject 'arch.trx'
        $behBase = Invoke-DotnetTest $base $behaviourProject[$copyName] 'behaviour.trx'
        if (-not ($archBase.ok -and $behBase.ok)) {
            throw "Baseline tests fail for $copyName; aborting.`n$($archBase.output)`n$($behBase.output)"
        }
        $dupBefore[$copyName] = Invoke-Jscpd $base
        # Kept in memory because the baseline copy is about to go: every run folder gets its own copy, so
        # dup_blocks_before can be re-derived from a results folder alone.
        $dupBeforeJson[$copyName] = Get-Content -LiteralPath (Join-Path $base '.jscpd-report/jscpd-report.json') -Raw -ErrorAction SilentlyContinue
        if (-not $KeepRuns) { Remove-Item -Recurse -Force $base }
    }

    # Task, then repetition, then copy: the two arms are interleaved so that anything that drifts over the
    # hours an experiment takes - a model update, machine load, a warm cache - lands on both copies alike
    # instead of on whichever one happened to run second.
    foreach ($taskFile in $taskFiles) {
        $spec = Get-TaskSpec -Path $taskFile.FullName
        for ($rep = 1; $rep -le $Repetitions; $rep++) {
            foreach ($copyName in $copies) {
                $runName = "$copyName-$($spec.id)-$rep"
                # Before the run, not only after it: the cap is a spending limit, so the run that would break it is the
                # one that must not start.
                if ($runningTotal + $MaxBudgetUsd -gt $MaxTotalUsd) {
                    throw "Next run could exceed -MaxTotalUsd $MaxTotalUsd (spent $runningTotal); stopping"
                }
                Write-Host "== run $runName ($($spec.title))"
                $startedAt = (Get-Date).ToUniversalTime()
                $dir = $null
                $keepThisRun = $false
                $rowModel = $null       # set only by a measured row, so a failed run cannot look like drift
                try {
                    $run = New-RunDirectory $copyName $runName
                    $dir = $run.dir
                    $baseSha = $run.baseSha
                    $artefacts = Join-Path $ResultsDir $runName
                    New-Item -ItemType Directory -Force -Path $artefacts | Out-Null
                    $promptFile = Join-Path $artefacts 'prompt.md'
                    Set-Content -Path $promptFile -Value $spec.prompt -Encoding utf8
                    $events = Join-Path $artefacts 'events.jsonl'

                    $agent = Invoke-Agent $dir $promptFile $events (Join-Path $artefacts 'stderr.txt')
                    # A CLI that writes nothing at all to stdout leaves Set-Content with no input, and no file to parse.
                    if (-not (Test-Path -LiteralPath $events)) { Set-Content -Path $events -Value '' -Encoding utf8 }
                    $m = ConvertFrom-AgentEvents -Path $events

                    Push-Location $dir
                    try {
                        & dotnet build --nologo -v q 2>&1 | Set-Content -Path (Join-Path $artefacts 'build.txt')
                        $buildOk = ($LASTEXITCODE -eq 0)
                    }
                    finally { Pop-Location }
                    $arch = Invoke-DotnetTest $dir $archProject 'arch.trx'
                    $beh = Invoke-DotnetTest $dir $behaviourProject[$copyName] 'behaviour.trx'
                    Set-Content -Path (Join-Path $artefacts 'test-output.txt') -Value ($arch.output + "`n`n" + $beh.output)
                    $archSum = Read-TrxSummary -Path $arch.trx
                    $behSum = Read-TrxSummary -Path $beh.trx
                    # The trx files and the "before" duplication report travel with the row, so every count in it
                    # can be re-derived from the results folder after the run directory is gone.
                    New-Item -ItemType Directory -Force -Path (Join-Path $artefacts 'trx') | Out-Null
                    Copy-Item -Path (Join-Path $dir '.trx/*.trx') -Destination (Join-Path $artefacts 'trx') -ErrorAction SilentlyContinue
                    if ($dupBeforeJson[$copyName]) { Set-Content -Path (Join-Path $artefacts 'jscpd-before.json') -Value $dupBeforeJson[$copyName] -Encoding utf8 }

                    Push-Location $dir
                    try {
                        & git @git add -A 2>&1 | Out-Null
                        if ($LASTEXITCODE -ne 0) { throw "git add -A failed in $dir" }
                        # Always against the baseline commit, never HEAD: an agent that commits its own work would
                        # otherwise measure as having changed nothing. --no-renames: a moved file counts as two files.
                        $changed = @(& git -c core.quotepath=false diff --cached --no-renames --name-only $baseSha)   # keep non-ASCII paths readable
                        $numstat = @(& git diff --cached --no-renames --numstat $baseSha)
                        & git -c core.quotepath=false diff --cached --no-renames $baseSha | Set-Content -Path (Join-Path $artefacts 'diff.patch') -Encoding utf8
                        $head = (& git rev-parse HEAD).Trim()
                        $agentCommits = if ($head -eq $baseSha) { 0 } else { [int](& git rev-list --count "$baseSha..HEAD").Trim() }
                    }
                    finally { Pop-Location }
                    $added = 0; $deleted = 0
                    foreach ($n in $numstat) {
                        $parts = $n -split "`t"
                        if ($parts[0] -match '^\d+$') { $added += [int]$parts[0]; $deleted += [int]$parts[1] }
                    }
                    $outOfScope = @($changed | Where-Object { -not (Test-PathInScope -Path $_ -Globs $spec.scope[$copyName]) })
                    Set-Content -Path (Join-Path $artefacts 'out-of-scope.txt') -Value ($outOfScope -join "`n")

                    $dupAfter = Invoke-Jscpd $dir
                    Copy-Item -Path (Join-Path $dir '.jscpd-report/jscpd-report.json') -Destination (Join-Path $artefacts 'jscpd.json') -ErrorAction SilentlyContinue

                    $gateBlocks = 0; $gateBlocksBuild = 0
                    $gateLog = Join-Path $dir '.gate.log'
                    if (Test-Path $gateLog) {
                        $blockLines = @(Get-Content $gateLog | Where-Object { $_ -match 'exit=2' })
                        $gateBlocks = $blockLines.Count
                        $gateBlocksBuild = @($blockLines | Where-Object { $_ -match ' build$' }).Count   # compile errors, not rule violations
                        Copy-Item -Path $gateLog -Destination (Join-Path $artefacts 'gate.log')
                    }

                    $notes = @()
                    if ($agent.exit -ne 0) { $notes += "claude exit $($agent.exit)" }
                    if (-not $m.saw_result) { $notes += 'no result event' }        # transcript stops mid-stream: cost and tokens are unknown, not zero
                    elseif ($m.ended -ne 'success') { $notes += "ended=$($m.ended)" }
                    if ($m.skipped_lines -gt 0) { $notes += "$($m.skipped_lines) unparsable event line$(if ($m.skipped_lines -ne 1) { 's' })" }
                    if ($m.permission_denials -gt 0) { $notes += "$($m.permission_denials) permission denials" }
                    if ($agentCommits -gt 0) { $notes += "agent committed ($agentCommits commit$(if ($agentCommits -ne 1) { 's' }))" }
                    if (-not $archSum.found) { $notes += 'no arch trx (build failed?)' }
                    if (-not $behSum.found) { $notes += 'no behaviour trx (build failed?)' }
                    if ($dupBefore[$copyName].sources -eq 0 -or $dupAfter.sources -eq 0) { $notes += 'jscpd analysed no files' }

                    $rowModel = $m.model
                    $row = New-ResultRow @{
                        # What ran, not what was asked for: the init event names the model the CLI chose, and
                        # modelUsage names everything it billed. -Model is only the fallback, 'default' the last one.
                        copy = $copyName; task = $spec.id; rep = $rep
                        model = $m.model ?? ($Model ? $Model : 'default'); models_billed = $m.models
                        started_at = ($startedAt.ToString('s') + 'Z'); wall_ms = $agent.wall_ms
                        cost_usd = $m.cost_usd; num_turns = $m.num_turns; duration_ms = $m.duration_ms; duration_api_ms = $m.duration_api_ms
                        input_tokens = $m.input_tokens; output_tokens = $m.output_tokens
                        cache_read_tokens = $m.cache_read_tokens; cache_create_tokens = $m.cache_create_tokens
                        ended = $m.ended; terminal_reason = $m.terminal_reason; stop_reason = $m.stop_reason
                        is_error = $m.is_error; permission_denials = $m.permission_denials; skipped_lines = $m.skipped_lines
                        files_read_distinct = $m.files_read_distinct; read_calls = $m.read_calls; grep_calls = $m.grep_calls; glob_calls = $m.glob_calls
                        edit_calls = $m.edit_calls; write_calls = $m.write_calls; bash_calls = $m.bash_calls; bash_search_calls = $m.bash_search_calls
                        gate_blocks = $gateBlocks; gate_blocks_build = $gateBlocksBuild
                        files_changed = $changed.Count; lines_added = $added; lines_deleted = $deleted; files_out_of_scope = $outOfScope.Count
                        build_ok = $buildOk
                        behaviour_tests_passed = $behSum.passed; behaviour_tests_failed = $behSum.failed
                        arch_tests_passed = $archSum.passed; arch_tests_failed = $archSum.failed
                        dup_blocks_before = $dupBefore[$copyName].clones; dup_blocks_after = $dupAfter.clones; dup_lines_pct_after = $dupAfter.percentage
                        notes = ($notes -join '; ')
                    }
                    $row | Export-Csv -Path $csv -Append -NoTypeInformation
                    $runningTotal += [double]($m.cost_usd ?? 0)
                    Write-Host ("   cost {0}  turns {1}  files_read {2}  changed {3}  out_of_scope {4}  build {5}  behaviour {6}/{7}  arch {8}/{9}  total so far `${10:N2}" -f
                        (Format-Metric $m.cost_usd '${0:N2}'), (Format-Metric $m.num_turns), $m.files_read_distinct, $changed.Count, $outOfScope.Count, $buildOk,
                        (Format-Metric $behSum.passed), (Format-Metric $behSum.total), (Format-Metric $archSum.passed), (Format-Metric $archSum.total), $runningTotal)
                }
                catch {
                    # One row per repetition, always: a harness failure is recorded where the numbers are, not only on screen.
                    # The copy stays on disk whatever -KeepRuns says, because it is the evidence for what went wrong.
                    $keepThisRun = $true
                    Write-Host "   harness error: $($_.Exception.Message)"
                    New-ResultRow @{
                        copy = $copyName; task = $spec.id; rep = $rep; model = ($Model ? $Model : 'default')
                        started_at = ($startedAt.ToString('s') + 'Z'); notes = "harness error: $($_.Exception.Message)"
                    } | Export-Csv -Path $csv -Append -NoTypeInformation
                }
                finally {
                    if ($dir -and $keepThisRun) { Write-Host "   Run directory kept for diagnosis: $dir" }
                    elseif ($dir -and -not $KeepRuns) { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
                }
                # Outside the catch: a runaway total stops the experiment instead of becoming one more row.
                if ($runningTotal -gt $MaxTotalUsd) { throw "Total cost `$$runningTotal exceeds -MaxTotalUsd `$$MaxTotalUsd; stopping" }
                # Comparing two arms only means something while the model stays the same. The row is already
                # written; what follows it would be a different experiment, so stop instead of mixing them.
                if ($rowModel) {
                    if ($null -eq $firstModel) { $firstModel = $rowModel }
                    elseif ($rowModel -ne $firstModel -and -not $Model) {
                        throw "primary model changed from $firstModel to $rowModel; stopping - pass -Model to pin it"
                    }
                }
            }
        }
    }
}
finally {
    # Whatever ended the experiment - a cost cap, a failing baseline, Ctrl+C - the rows written so far are here.
    Write-Host "Results: $csv"
}
