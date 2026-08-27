#requires -Version 7
# Plain assertions, no Pester dependency. Run: pwsh experiment/Test-ParseEvents.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Parse-Events.ps1"

$failures = 0
function Assert-Equal($expected, $actual, $name) {
    if ("$expected" -ne "$actual") { Write-Host "FAIL $name : expected '$expected', got '$actual'"; $script:failures++ }
    else { Write-Host "ok   $name" }
}
function New-TempFile([string]$name, [string]$content) {
    $p = Join-Path ([IO.Path]::GetTempPath()) $name
    Set-Content -LiteralPath $p -Value $content -Encoding utf8
    return $p
}

$fixtures = "$PSScriptRoot/fixtures"
$m = ConvertFrom-AgentEvents -Path "$fixtures/sample-events.jsonl"
Assert-Equal 3 $m.read_calls 'read_calls'
Assert-Equal 1 $m.files_read_distinct 'files_read_distinct (case- and separator-insensitive)'
Assert-Equal 1 $m.grep_calls 'grep_calls (re-emitted tool_use id counted once)'
Assert-Equal 0 $m.glob_calls 'glob_calls'
Assert-Equal 1 $m.edit_calls 'edit_calls (re-emitted tool_use id counted once)'
Assert-Equal 0 $m.write_calls 'write_calls'
Assert-Equal 1 $m.bash_calls 'bash_calls'
Assert-Equal 1 $m.bash_search_calls 'bash_search_calls'
Assert-Equal 1 $m.skipped_lines 'skipped_lines (one truncated event line)'
Assert-Equal $true $m.saw_result 'saw_result'
Assert-Equal 0.17785 $m.cost_usd 'cost_usd'
Assert-Equal 5 $m.num_turns 'num_turns'
Assert-Equal 19662 $m.duration_ms 'duration_ms'
Assert-Equal 8241 $m.duration_api_ms 'duration_api_ms'
Assert-Equal 10 $m.input_tokens 'input_tokens'
Assert-Equal 939 $m.output_tokens 'output_tokens'
Assert-Equal 135344 $m.cache_read_tokens 'cache_read_tokens'
Assert-Equal 8569 $m.cache_create_tokens 'cache_create_tokens'
Assert-Equal 'success' $m.ended 'ended'
Assert-Equal 'completed' $m.terminal_reason 'terminal_reason'
Assert-Equal 'end_turn' $m.stop_reason 'stop_reason'
Assert-Equal $false $m.is_error 'is_error'
Assert-Equal 1 $m.permission_denials 'permission_denials'
Assert-Equal 'claude-fable-5+claude-haiku-4-5' $m.models 'models (modelUsage keys, sorted, not in source order)'

# A transcript that stops before the result event: every result field stays $null, saw_result is $false.
$truncated = New-TempFile 'parse-events-truncated.jsonl' ((Get-Content -LiteralPath "$fixtures/sample-events.jsonl" | Select-Object -First 6) -join "`n")
$tr = ConvertFrom-AgentEvents -Path $truncated
Assert-Equal $false $tr.saw_result 'truncated: saw_result'
Assert-Equal $null $tr.ended 'truncated: ended is null'
Assert-Equal $null $tr.terminal_reason 'truncated: terminal_reason is null'
Assert-Equal $null $tr.stop_reason 'truncated: stop_reason is null'
Assert-Equal $null $tr.cost_usd 'truncated: cost_usd is null'
Assert-Equal $null $tr.is_error 'truncated: is_error is null'
Assert-Equal $null $tr.models 'truncated: models is null'
Assert-Equal 0 $tr.permission_denials 'truncated: permission_denials'
Assert-Equal 0 $tr.skipped_lines 'truncated: skipped_lines'
Assert-Equal 2 $tr.read_calls 'truncated: tool calls up to the cut are still counted'
Remove-Item -LiteralPath $truncated

# A result event without a permission_denials key must be 0, not 1 (@($null).Count is 1).
$noDenials = New-TempFile 'parse-events-no-denials.jsonl' '{"type":"result","subtype":"success","is_error":false,"num_turns":1,"total_cost_usd":0.01}'
$nd = ConvertFrom-AgentEvents -Path $noDenials
Assert-Equal 0 $nd.permission_denials 'result without permission_denials -> 0'
Assert-Equal $true $nd.saw_result 'result without permission_denials -> saw_result'
Assert-Equal $null $nd.terminal_reason 'result without terminal_reason -> null'
Assert-Equal $null $nd.models 'result without modelUsage -> models is null'
Remove-Item -LiteralPath $noDenials

$spec = Get-TaskSpec -Path "$fixtures/sample-task.md"
Assert-Equal 'T9' $spec.id 'task id'
Assert-Equal 'Sample task' $spec.title 'task title'
Assert-Equal 2 $spec.scope.sliced.Count 'scope.sliced count'
Assert-Equal 1 $spec.scope.layered.Count 'scope.layered count'
Assert-Equal "Do the thing.`nThen do the other thing." $spec.prompt 'prompt body'

# Relative paths must resolve against $PWD, not the process working directory.
Push-Location -LiteralPath $fixtures
try {
    Assert-Equal 3 (ConvertFrom-AgentEvents -Path 'sample-events.jsonl').read_calls 'relative path: ConvertFrom-AgentEvents'
    Assert-Equal 'T9' (Get-TaskSpec -Path './sample-task.md').id 'relative path: Get-TaskSpec'
}
finally { Pop-Location }

$noScope = New-TempFile 'parse-events-no-scope.md' "---`nid: T0`ntitle: No layered scope`nkind: slice-local`nscope.sliced: src/**`n---`nBody."
$ns = Get-TaskSpec -Path $noScope
Assert-Equal $false ($null -eq $ns.scope.layered) 'missing scope.layered is an empty list, not null'
Assert-Equal 0 $ns.scope.layered.Count 'missing scope.layered -> count 0'
Assert-Equal $false (Test-PathInScope -Path 'src/x.cs' -Globs $ns.scope.layered) 'empty glob list -> out of scope'
Assert-Equal $false (Test-PathInScope -Path 'src/x.cs' -Globs $null) 'null glob list -> out of scope'
Remove-Item -LiteralPath $noScope

Assert-Equal '^src/Orders\.Api/Features/Ship[^/]*/.*$' (ConvertTo-GlobRegex 'src/Orders.Api/Features/Ship*/**') 'glob regex'
Assert-Equal $true (Test-PathInScope -Path 'src/Orders.Api/Features/ShipOrder/ShipOrderHandler.cs' -Globs $spec.scope.sliced) 'in scope'
Assert-Equal $true (Test-PathInScope -Path 'tests\Orders.SliceTests\ShipOrderTests.cs' -Globs $spec.scope.sliced) 'in scope, backslashes'
Assert-Equal $false (Test-PathInScope -Path 'src/Orders.Api/Domain/Order.cs' -Globs $spec.scope.sliced) 'out of scope'

$trxCounters = @'
<?xml version="1.0" encoding="utf-8"?>
<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <ResultSummary outcome="Failed"><Counters total="13" executed="13" passed="12" failed="1" /></ResultSummary>
</TestRun>
'@
$trxNoCounters = @'
<?xml version="1.0" encoding="utf-8"?>
<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <ResultSummary outcome="Failed" />
</TestRun>
'@
$trx = New-TempFile 'parse-events-sample.trx' $trxCounters
$t = Read-TrxSummary -Path $trx
Assert-Equal $true $t.found 'trx found'
Assert-Equal 13 $t.total 'trx total'
Assert-Equal 12 $t.passed 'trx passed'
Assert-Equal 1 $t.failed 'trx failed'
Remove-Item -LiteralPath $trx

$trxEmpty = New-TempFile 'parse-events-no-counters.trx' $trxNoCounters
$te = Read-TrxSummary -Path $trxEmpty
Assert-Equal $false $te.found 'trx without Counters -> found false'
Assert-Equal $null $te.failed 'trx without Counters -> failed is null, not 0'
Remove-Item -LiteralPath $trxEmpty

$trxBroken = New-TempFile 'parse-events-broken.trx' '<TestRun><ResultSummary>'
$tb = Read-TrxSummary -Path $trxBroken
Assert-Equal $false $tb.found 'unparsable trx -> found false'
Assert-Equal $null $tb.total 'unparsable trx -> total is null'
Remove-Item -LiteralPath $trxBroken

$trxMissing = Read-TrxSummary -Path (Join-Path ([IO.Path]::GetTempPath()) 'does-not-exist.trx')
Assert-Equal $false $trxMissing.found 'missing trx -> found false'
Assert-Equal $null $trxMissing.passed 'missing trx -> passed is null'

$jscpd = New-TempFile 'parse-events-sample-jscpd.json' '{"statistics":{"total":{"lines":100,"sources":5,"clones":2,"duplicatedLines":12,"percentage":12.0}}}'
$j = Read-JscpdSummary -Path $jscpd
Assert-Equal $true $j.found 'jscpd found'
Assert-Equal 5 $j.sources 'jscpd sources'
Assert-Equal 2 $j.clones 'jscpd clones'
Assert-Equal 12 $j.percentage 'jscpd percentage'
Remove-Item -LiteralPath $jscpd

$jscpdBroken = New-TempFile 'parse-events-broken-jscpd.json' '{"statistics":'
$jb = Read-JscpdSummary -Path $jscpdBroken
Assert-Equal $false $jb.found 'unparsable jscpd report -> found false'
Assert-Equal 0 $jb.sources 'unparsable jscpd report -> sources 0'
Remove-Item -LiteralPath $jscpdBroken

$missing = Read-JscpdSummary -Path (Join-Path ([IO.Path]::GetTempPath()) 'does-not-exist-jscpd.json')
Assert-Equal $false $missing.found 'missing jscpd report -> found false'
Assert-Equal 0 $missing.sources 'missing jscpd report -> sources 0'

if ($failures -gt 0) { Write-Host "$failures assertion(s) failed"; exit 1 }
Write-Host 'Test-ParseEvents: all assertions passed'
