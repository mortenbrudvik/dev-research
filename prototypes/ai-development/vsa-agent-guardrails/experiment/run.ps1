#requires -Version 7
<#
.SYNOPSIS
  Runs Claude Code headlessly against the sliced and layered copies on the experiment tasks and records metrics.
.DESCRIPTION
  Per copy x task x repetition: copies the variant to %TEMP%\vsa-runs\<name>, makes it a git repo with one baseline commit,
  runs `claude -p` with the prompt on stdin (spec 5.2), then builds, tests, diffs, runs jscpd, and appends one CSV row.
.EXAMPLE
  pwsh experiment/run.ps1 -Copy sliced -Task T1 -Repetitions 1        # smoke run
  pwsh experiment/run.ps1                                              # full experiment: both copies, all tasks, 3 reps
#>
[CmdletBinding()]
param(
    [ValidateSet('sliced', 'layered', 'both')] [string]$Copy = 'both',
    [string[]]$Task = @('all'),
    [int]$Repetitions = 3,
    [double]$MaxBudgetUsd = 8,
    [string]$Model,
    [string]$ResultsDir,
    [switch]$KeepRuns
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

. "$PSScriptRoot/Parse-Events.ps1"

$root = Split-Path -Path $PSScriptRoot -Parent
$claude = (Get-Command -Name claude -ErrorAction Stop).Source
$copies = if ($Copy -eq 'both') { @('sliced', 'layered') } else { @($Copy) }
$taskFiles = @(Get-ChildItem -Path "$PSScriptRoot/tasks" -Filter 'T*.md' | Sort-Object Name)
if ($Task -notcontains 'all') { $taskFiles = @($taskFiles | Where-Object { $Task -contains ($_.BaseName -split '-')[0] }) }
if ($taskFiles.Count -eq 0) { throw "No task files match -Task $($Task -join ',')" }
if (-not $ResultsDir) { $ResultsDir = Join-Path $PSScriptRoot "results/$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
$ResultsDir = (Resolve-Path -LiteralPath $ResultsDir).Path        # a relative -ResultsDir must survive Push-Location
$csv = Join-Path $ResultsDir 'results.csv'
$runsRoot = Join-Path $env:TEMP 'vsa-runs'
$behaviourProject = @{ sliced = 'tests/Orders.SliceTests'; layered = 'tests/Orders.IntegrationTests' }
$archProject = 'tests/Orders.ArchitectureTests'
$git = @('-c', 'user.name=runner', '-c', 'user.email=runner@example.invalid')

function New-RunDirectory([string]$copyName, [string]$runName) {
    $src = Join-Path $root $copyName
    $dst = Join-Path $runsRoot $runName
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    & robocopy $src $dst /E /XD bin obj .jscpd-report .trx /XF *.db *.db-shm *.db-wal .gate.log /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $src -> $dst failed with exit code $LASTEXITCODE" }
    Push-Location $dst
    try {
        & dotnet tool restore 2>&1 | Out-Null          # makes `dotnet ef` available in the fresh copy (local tool manifest)
        & git init -q
        & git @git add -A
        & git @git commit -q -m 'baseline'
        if ($LASTEXITCODE -ne 0) { throw "baseline commit failed in $dst" }
    }
    finally { Pop-Location }
    return $dst
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
        '--disallowedTools', 'Bash(cat *),Bash(head *),Bash(tail *),Bash(sed *),Bash(type *)',
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
foreach ($copyName in $copies) {
    Write-Host "== baseline check: $copyName"
    $base = New-RunDirectory $copyName "$copyName-baseline"
    $archBase = Invoke-DotnetTest $base $archProject 'arch.trx'
    $behBase = Invoke-DotnetTest $base $behaviourProject[$copyName] 'behaviour.trx'
    if (-not ($archBase.ok -and $behBase.ok)) {
        throw "Baseline tests fail for $copyName; aborting.`n$($archBase.output)`n$($behBase.output)"
    }
    $dupBefore = Invoke-Jscpd $base
    if (-not $KeepRuns) { Remove-Item -Recurse -Force $base }

    foreach ($taskFile in $taskFiles) {
        $spec = Get-TaskSpec -Path $taskFile.FullName
        for ($rep = 1; $rep -le $Repetitions; $rep++) {
            $runName = "$copyName-$($spec.id)-$rep"
            Write-Host "== run $runName ($($spec.title))"
            $startedAt = Get-Date
            $dir = New-RunDirectory $copyName $runName
            $artefacts = Join-Path $ResultsDir $runName
            New-Item -ItemType Directory -Force -Path $artefacts | Out-Null
            $promptFile = Join-Path $artefacts 'prompt.md'
            Set-Content -Path $promptFile -Value $spec.prompt -Encoding utf8
            $events = Join-Path $artefacts 'events.jsonl'

            $agent = Invoke-Agent $dir $promptFile $events (Join-Path $artefacts 'stderr.txt')
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

            Push-Location $dir
            try {
                & git @git add -A
                $changed = @(& git -c core.quotepath=false diff --cached --name-only)   # keep non-ASCII paths readable
                $numstat = @(& git diff --cached --numstat)
                & git diff --cached | Set-Content -Path (Join-Path $artefacts 'diff.patch') -Encoding utf8
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
            if ($m.skipped_lines -gt 0) { $notes += "$($m.skipped_lines) unparsable event lines" }
            if ($m.permission_denials -gt 0) { $notes += "$($m.permission_denials) permission denials" }
            if (-not $archSum.found) { $notes += 'no arch trx (build failed?)' }
            if (-not $behSum.found) { $notes += 'no behaviour trx (build failed?)' }
            if ($dupBefore.sources -eq 0 -or $dupAfter.sources -eq 0) { $notes += 'jscpd analysed no files' }

            $row = [pscustomobject][ordered]@{
                copy = $copyName; task = $spec.id; rep = $rep; model = ($Model ? $Model : 'default')
                started_at = $startedAt.ToString('s'); wall_ms = $agent.wall_ms
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
                dup_blocks_before = $dupBefore.clones; dup_blocks_after = $dupAfter.clones; dup_lines_pct_after = $dupAfter.percentage
                notes = ($notes -join '; ')
            }
            $row | Export-Csv -Path $csv -Append -NoTypeInformation
            $runningTotal += [double]($m.cost_usd ?? 0)
            Write-Host ("   cost `${0:N2}  turns {1}  files_read {2}  changed {3}  out_of_scope {4}  build {5}  behaviour {6}/{7}  arch {8}/{9}  total so far `${10:N2}" -f
                $m.cost_usd, $m.num_turns, $m.files_read_distinct, $changed.Count, $outOfScope.Count, $buildOk,
                $behSum.passed, $behSum.total, $archSum.passed, $archSum.total, $runningTotal)

            if (-not $KeepRuns) { Remove-Item -Recurse -Force $dir }
        }
    }
}
Write-Host "Results: $csv"
