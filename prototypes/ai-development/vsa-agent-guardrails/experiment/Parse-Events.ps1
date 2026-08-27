#requires -Version 7
# Pure functions used by run.ps1. Dot-source this file. Tested by Test-ParseEvents.ps1.

function Get-Prop($object, [string]$name) {
    # Property access that returns $null instead of throwing when the property is absent.
    if ($null -eq $object) { return $null }
    $p = $object.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function ConvertFrom-AgentEvents {
    # Reads a `claude -p --output-format stream-json --verbose` transcript and returns one metrics object.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $m = [ordered]@{
        read_calls = 0; grep_calls = 0; glob_calls = 0; edit_calls = 0; write_calls = 0
        bash_calls = 0; bash_search_calls = 0; files_read_distinct = 0
        cost_usd = $null; num_turns = $null; duration_ms = $null; duration_api_ms = $null
        input_tokens = $null; output_tokens = $null; cache_read_tokens = $null; cache_create_tokens = $null
        ended = $null; is_error = $null; permission_denials = 0
    }
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $e = $line | ConvertFrom-Json -Depth 100 } catch { continue }
        switch (Get-Prop $e 'type') {
            'assistant' {
                foreach ($block in @(Get-Prop (Get-Prop $e 'message') 'content')) {
                    if ((Get-Prop $block 'type') -ne 'tool_use') { continue }
                    $input = Get-Prop $block 'input'
                    switch (Get-Prop $block 'name') {
                        'Read'  { $m.read_calls++; $f = Get-Prop $input 'file_path'; if ($f) { [void]$files.Add([string]$f) } }
                        'Grep'  { $m.grep_calls++ }
                        'Glob'  { $m.glob_calls++ }
                        'Edit'  { $m.edit_calls++ }
                        'Write' { $m.write_calls++ }
                        'Bash'  {
                            $m.bash_calls++
                            if ([string](Get-Prop $input 'command') -match '^\s*(ls|dir|find|grep|rg|git\s+grep)\b') { $m.bash_search_calls++ }
                        }
                    }
                }
            }
            'result' {
                $m.cost_usd = Get-Prop $e 'total_cost_usd'
                $m.num_turns = Get-Prop $e 'num_turns'
                $m.duration_ms = Get-Prop $e 'duration_ms'
                $m.duration_api_ms = Get-Prop $e 'duration_api_ms'
                $m.ended = Get-Prop $e 'subtype'
                $m.is_error = [bool](Get-Prop $e 'is_error')
                $usage = Get-Prop $e 'usage'
                $m.input_tokens = Get-Prop $usage 'input_tokens'
                $m.output_tokens = Get-Prop $usage 'output_tokens'
                $m.cache_read_tokens = Get-Prop $usage 'cache_read_input_tokens'
                $m.cache_create_tokens = Get-Prop $usage 'cache_creation_input_tokens'
                $m.permission_denials = @(Get-Prop $e 'permission_denials').Count
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

    $lines = @(Get-Content -Path $Path -Encoding utf8)
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

    return [pscustomobject]@{
        id     = $meta['id']
        title  = $meta['title']
        kind   = $meta['kind']
        scope  = @{ sliced = Split-Globs $meta['scope.sliced']; layered = Split-Globs $meta['scope.layered'] }
        prompt = $body
        path   = $Path
    }
}

function ConvertTo-GlobRegex {
    # `*` = one path segment, `**` = any depth, `?` = one character. Paths are compared with forward slashes.
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
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Globs)

    $p = $Path -replace '\\', '/'
    foreach ($glob in $Globs) {
        if ($p -match (ConvertTo-GlobRegex -Glob $glob)) { return $true }
    }
    return $false
}

function Read-TrxSummary {
    # Reads the Counters element of a VSTest .trx file.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) { return [pscustomobject]@{ total = $null; passed = $null; failed = $null } }
    [xml]$x = Get-Content -Path $Path -Raw
    $c = $x.TestRun.ResultSummary.Counters
    return [pscustomobject]@{ total = [int]$c.total; passed = [int]$c.passed; failed = [int]$c.failed }
}

function Read-JscpdSummary {
    # Reads statistics.total from jscpd's JSON reporter output. sources == 0 means jscpd analysed nothing.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) { return [pscustomobject]@{ sources = 0; clones = $null; percentage = $null } }
    $j = Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 20
    return [pscustomobject]@{
        sources    = [int]$j.statistics.total.sources
        clones     = [int]$j.statistics.total.clones
        percentage = [double]$j.statistics.total.percentage
    }
}
