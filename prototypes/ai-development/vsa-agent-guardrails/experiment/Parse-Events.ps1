#requires -Version 7
# Pure functions used by run.ps1. Dot-source this file. Tested by Test-ParseEvents.ps1.
# Every -Path is resolved against $PWD on entry: .NET APIs resolve relative paths against the process
# working directory, which diverges from $PWD as soon as the runner does Push-Location.

function Get-Prop($object, [string]$name) {
    # Property access that returns $null instead of throwing when the property is absent.
    if ($null -eq $object) { return $null }
    $p = $object.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function ConvertFrom-AgentEvents {
    # Reads a `claude -p --output-format stream-json --verbose` transcript and returns one metrics object.
    # saw_result distinguishes "the run reported success" from "the transcript stops mid-stream"; a
    # killed or truncated run leaves every result field $null, which must not be read as a zero.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)

    $m = [ordered]@{
        read_calls = 0; grep_calls = 0; glob_calls = 0; edit_calls = 0; write_calls = 0
        bash_calls = 0; bash_search_calls = 0; files_read_distinct = 0
        cost_usd = $null; num_turns = $null; duration_ms = $null; duration_api_ms = $null
        input_tokens = $null; output_tokens = $null; cache_read_tokens = $null; cache_create_tokens = $null
        ended = $null; terminal_reason = $null; stop_reason = $null; is_error = $null
        permission_denials = 0; saw_result = $false; skipped_lines = 0
    }
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $seenToolIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $e = $line | ConvertFrom-Json } catch { $m.skipped_lines++; continue }
        switch (Get-Prop $e 'type') {
            'assistant' {
                foreach ($block in @(Get-Prop (Get-Prop $e 'message') 'content')) {
                    if ((Get-Prop $block 'type') -ne 'tool_use') { continue }
                    # The CLI can emit the same assistant message twice (once with its thinking block,
                    # once with the tool_use block), so count each tool_use id at most once.
                    $id = Get-Prop $block 'id'
                    if ($id -and -not $seenToolIds.Add([string]$id)) { continue }
                    $toolInput = Get-Prop $block 'input'
                    switch (Get-Prop $block 'name') {
                        'Read'  {
                            $m.read_calls++
                            $f = Get-Prop $toolInput 'file_path'
                            if ($f) { [void]$files.Add(([string]$f -replace '\\', '/')) }   # same file, either separator
                        }
                        'Grep'  { $m.grep_calls++ }
                        'Glob'  { $m.glob_calls++ }
                        'Edit'  { $m.edit_calls++ }
                        'Write' { $m.write_calls++ }
                        'Bash'  {
                            $m.bash_calls++
                            if ([string](Get-Prop $toolInput 'command') -match '^\s*(ls|dir|find|grep|rg|git\s+grep)\b') { $m.bash_search_calls++ }
                        }
                    }
                }
            }
            'result' {
                $m.saw_result = $true
                $m.cost_usd = Get-Prop $e 'total_cost_usd'
                $m.num_turns = Get-Prop $e 'num_turns'
                $m.duration_ms = Get-Prop $e 'duration_ms'
                $m.duration_api_ms = Get-Prop $e 'duration_api_ms'
                $m.ended = Get-Prop $e 'subtype'
                $m.terminal_reason = Get-Prop $e 'terminal_reason'   # verbatim, e.g. budget_exhausted
                $m.stop_reason = Get-Prop $e 'stop_reason'           # verbatim, e.g. end_turn
                $m.is_error = [bool](Get-Prop $e 'is_error')
                $usage = Get-Prop $e 'usage'
                $m.input_tokens = Get-Prop $usage 'input_tokens'
                $m.output_tokens = Get-Prop $usage 'output_tokens'
                $m.cache_read_tokens = Get-Prop $usage 'cache_read_input_tokens'
                $m.cache_create_tokens = Get-Prop $usage 'cache_creation_input_tokens'
                $denials = Get-Prop $e 'permission_denials'
                $m.permission_denials = if ($null -eq $denials) { 0 } else { @($denials).Count }   # @($null).Count is 1
            }
        }
    }
    $m.files_read_distinct = $files.Count
    return [pscustomobject]$m
}

function Get-TaskSpec {
    # Parses a task file: `key: value` front matter between --- fences, then the prompt body.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)

    $lines = @(Get-Content -LiteralPath $Path -Encoding utf8)
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') { throw "Task file $Path has no front matter" }
    $end = 1
    while ($end -lt $lines.Count -and $lines[$end].Trim() -ne '---') { $end++ }
    if ($end -ge $lines.Count) { throw "Task file $Path has an unterminated front matter block" }

    $meta = @{}
    foreach ($l in $lines[1..($end - 1)]) {
        if ($l -match '^([A-Za-z0-9_.]+):\s*(.*)$') { $meta[$Matches[1]] = $Matches[2].Trim() }
    }
    $body = if ($end + 1 -lt $lines.Count) { ($lines[($end + 1)..($lines.Count - 1)] -join "`n").Trim() } else { '' }

    function Split-Globs([string]$value) { @($value -split ',\s*' | Where-Object { $_ -ne '' }) }

    # A function returning an empty array yields nothing, which lands as $null; @(...) at the call site
    # keeps an absent scope an empty list, so "no scope" never silently becomes "everything is in scope".
    return [pscustomobject]@{
        id     = $meta['id']
        title  = $meta['title']
        kind   = $meta['kind']
        scope  = @{ sliced = @(Split-Globs $meta['scope.sliced']); layered = @(Split-Globs $meta['scope.layered']) }
        prompt = $body
        path   = $Path
    }
}

function ConvertTo-GlobRegex {
    # `*` = one path segment, `**` = any depth, `?` = one character. Paths are compared with forward slashes.
    # Callers match with -match, which is case-insensitive, and .NET's `$` also matches before a trailing
    # newline. Git paths are case-sensitive, so this is looser than git on Linux; on Windows, where the
    # experiment runs and the filesystem is case-insensitive anyway, it is the behaviour we want.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Glob)

    $g = $Glob -replace '\\', '/'
    $sb = [System.Text.StringBuilder]::new('^')
    $i = 0
    while ($i -lt $g.Length) {
        $c = $g[$i]
        if ($c -eq '*') {
            if ($i + 1 -lt $g.Length -and $g[$i + 1] -eq '*') {
                if ($i + 2 -lt $g.Length -and $g[$i + 2] -eq '/') { [void]$sb.Append('(?:.*/)?'); $i += 3 }
                else { [void]$sb.Append('.*'); $i += 2 }
            }
            else { [void]$sb.Append('[^/]*'); $i++ }
        }
        elseif ($c -eq '?') { [void]$sb.Append('[^/]'); $i++ }
        else { [void]$sb.Append([regex]::Escape([string]$c)); $i++ }
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-PathInScope {
    # An empty or absent glob list means "nothing is in scope", never "everything is".
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][string[]]$Globs
    )

    if ($null -eq $Globs -or $Globs.Count -eq 0) { return $false }
    $p = $Path -replace '\\', '/'
    foreach ($glob in $Globs) {
        if ($p -match (ConvertTo-GlobRegex -Glob $glob)) { return $true }
    }
    return $false
}

function Read-TrxSummary {
    # Reads the Counters element of a VSTest .trx file. found is $false when the file is missing,
    # unparsable or has no Counters; the counts are then $null, so "no test run" is never read as
    # "zero failures" — the runner turns a missing summary into a note instead of a green row.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
    $none = [pscustomobject]@{ found = $false; total = $null; passed = $null; failed = $null }
    if (-not (Test-Path -LiteralPath $Path)) { return $none }
    try { [xml]$x = Get-Content -LiteralPath $Path -Raw } catch { return $none }
    $c = $x.TestRun.ResultSummary.Counters
    if ($null -eq $c) { return $none }
    return [pscustomobject]@{ found = $true; total = [int]$c.total; passed = [int]$c.passed; failed = [int]$c.failed }
}

function Read-JscpdSummary {
    # Reads statistics.total from jscpd's JSON reporter output. found is $false when the report is
    # missing, unparsable or shaped differently; sources == 0 also means jscpd analysed nothing.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
    $none = [pscustomobject]@{ found = $false; sources = 0; clones = $null; percentage = $null }
    if (-not (Test-Path -LiteralPath $Path)) { return $none }
    try { $j = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json } catch { return $none }
    $total = Get-Prop (Get-Prop $j 'statistics') 'total'
    if ($null -eq $total) { return $none }
    return [pscustomobject]@{
        found      = $true
        sources    = [int]$total.sources
        clones     = [int]$total.clones
        percentage = [double]$total.percentage
    }
}
