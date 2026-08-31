#requires -Version 7
# Aggregates one or more results.csv into the shape REPORT.md wants: per copy x task, the median and range of the
# reported columns, plus the green fraction. Run: pwsh experiment/Summarize-Results.ps1 -Path results/<stamp>/results.csv
# -Markdown emits the REPORT table rows; without it you get a readable grid plus the per-task deltas.
param(
    [Parameter(Mandatory)] [string[]]$Path,
    [switch]$Markdown
)
$ErrorActionPreference = 'Stop'

# Median of an even-sized set is the mean of the two middle values; with 3 repetitions it is always the middle one.
function Get-Median([double[]]$values) {
    if ($values.Count -eq 0) { return $null }
    $s = @($values | Sort-Object)
    $mid = [int][math]::Floor($s.Count / 2)
    if ($s.Count % 2 -eq 1) { return $s[$mid] }
    return ($s[$mid - 1] + $s[$mid]) / 2
}

function Format-Number([double]$value) {
    if ([math]::Abs($value) -ge 1000) { return '{0:N0}' -f $value }
    if ([math]::Abs($value - [math]::Round($value)) -lt 0.005) { return '{0:N0}' -f $value }
    return '{0:N2}' -f $value
}

# "12 (10-15)", or just "12" when every repetition agreed.
function Format-Cell([double[]]$values) {
    if ($values.Count -eq 0) { return '' }
    $median = Format-Number (Get-Median $values)
    $min = Format-Number ($values | Measure-Object -Minimum).Minimum
    $max = Format-Number ($values | Measure-Object -Maximum).Maximum
    if ($min -eq $max) { return $median }
    return "$median ($min-$max)"
}

$rows = @()
foreach ($p in $Path) {
    $resolved = (Resolve-Path -LiteralPath $p).Path
    $rows += @(Import-Csv -LiteralPath $resolved)
}
if ($rows.Count -eq 0) { throw "No rows in: $($Path -join ', ')" }

# A run can fail two ways, and neither may enter the statistics:
#   no result event at all  -> empty numeric cells (the CLI died before finishing)
#   a result event that is an error -> is_error True; a provider rate limit (terminal_reason api_error, HTTP 429)
#     still reports subtype "success", so `ended` alone reads as a clean run. It is not one: the agent never worked,
#     the tree is untouched, and the build and tests therefore pass — which would otherwise score as a green run.
$failed = @($rows | Where-Object { -not $_.cost_usd -or $_.is_error -eq 'True' })
$measured = @($rows | Where-Object { $_.cost_usd -and $_.is_error -ne 'True' })

$metrics = [ordered]@{
    'files read'     = 'files_read_distinct'
    'context tokens' = 'cache_create_tokens'
    'cost USD'       = 'cost_usd'
    'turns'          = 'num_turns'
    'files changed'  = 'files_changed'
    'out of scope'   = 'files_out_of_scope'
}

$taskOrder = @($rows.task | Sort-Object -Unique)
$copyOrder = @('sliced', 'layered')

$summary = foreach ($task in $taskOrder) {
    foreach ($copy in $copyOrder) {
        $group = @($measured | Where-Object { $_.task -eq $task -and $_.copy -eq $copy })
        $all = @($rows | Where-Object { $_.task -eq $task -and $_.copy -eq $copy })
        if ($all.Count -eq 0) { continue }
        # Green is scored over the runs the agent actually completed, never over the attempts.
        $green = @($group | Where-Object {
                $_.build_ok -eq 'True' -and $_.behaviour_tests_failed -eq '0' -and $_.arch_tests_failed -eq '0'
            })
        $record = [ordered]@{ task = $task; copy = $copy }
        foreach ($label in $metrics.Keys) {
            $column = $metrics[$label]
            $record[$label] = Format-Cell @($group | ForEach-Object { [double]$_.$column })
        }
        $record['green'] = "$($green.Count)/$($group.Count)"
        $record['dup delta'] = Format-Cell @($group | ForEach-Object { [double]$_.dup_blocks_after - [double]$_.dup_blocks_before })
        $record['gate blocks'] = Format-Cell @($group | ForEach-Object { [double]$_.gate_blocks })
        $record['gate build'] = Format-Cell @($group | ForEach-Object { [double]$_.gate_blocks_build })
        [pscustomobject]$record
    }
}

if ($Markdown) {
    "| Task | Copy | files read | context tokens | cost USD | turns | files changed | out of scope | green runs |"
    "|---|---|---|---|---|---|---|---|---|"
    foreach ($r in $summary) {
        "| $($r.task) | $($r.copy) | $($r.'files read') | $($r.'context tokens') | $($r.'cost USD') | $($r.turns) | $($r.'files changed') | $($r.'out of scope') | $($r.green) |"
    }
    ''
    "Duplication and gate blocks per task (median, range): "
    foreach ($r in $summary) {
        "- $($r.task) $($r.copy): dup delta $($r.'dup delta'), gate blocks $($r.'gate blocks') (of which build $($r.'gate build'))"
    }
}
else {
    $summary | Format-Table -AutoSize | Out-String -Width 200
    $total = ($rows | Where-Object { $_.cost_usd } | Measure-Object -Property cost_usd -Sum).Sum
    "runs: $($rows.Count) ($($measured.Count) completed, $($failed.Count) failed and excluded)"
    "total cost: `$$('{0:N2}' -f $total)"
    foreach ($f in $failed) {
        $why = if ($f.is_error -eq 'True') { "is_error, terminal_reason=$($f.terminal_reason)" } else { 'no result event' }
        "  FAILED $($f.copy)-$($f.task)-$($f.rep): $why"
    }
    $models = @($rows.model | Sort-Object -Unique)
    "models: $($models -join ', ')"
    $noted = @($rows | Where-Object { $_.notes })
    if ($noted) {
        'notes:'
        foreach ($r in $noted) { "  $($r.copy)-$($r.task)-$($r.rep): $($r.notes)" }
    }
}
