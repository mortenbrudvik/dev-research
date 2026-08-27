#requires -Version 7
# Plain assertions, no Pester dependency. Run: pwsh experiment/Test-ParseEvents.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Parse-Events.ps1"

$failures = 0
function Assert-Equal($expected, $actual, $name) {
    if ("$expected" -ne "$actual") { Write-Host "FAIL $name : expected '$expected', got '$actual'"; $script:failures++ }
    else { Write-Host "ok   $name" }
}

$m = ConvertFrom-AgentEvents -Path "$PSScriptRoot/fixtures/sample-events.jsonl"
Assert-Equal 2 $m.read_calls 'read_calls'
Assert-Equal 1 $m.files_read_distinct 'files_read_distinct (case-insensitive)'
Assert-Equal 1 $m.grep_calls 'grep_calls'
Assert-Equal 0 $m.glob_calls 'glob_calls'
Assert-Equal 1 $m.edit_calls 'edit_calls'
Assert-Equal 0 $m.write_calls 'write_calls'
Assert-Equal 1 $m.bash_calls 'bash_calls'
Assert-Equal 1 $m.bash_search_calls 'bash_search_calls'
Assert-Equal 0.17785 $m.cost_usd 'cost_usd'
Assert-Equal 5 $m.num_turns 'num_turns'
Assert-Equal 19662 $m.duration_ms 'duration_ms'
Assert-Equal 8241 $m.duration_api_ms 'duration_api_ms'
Assert-Equal 10 $m.input_tokens 'input_tokens'
Assert-Equal 939 $m.output_tokens 'output_tokens'
Assert-Equal 135344 $m.cache_read_tokens 'cache_read_tokens'
Assert-Equal 8569 $m.cache_create_tokens 'cache_create_tokens'
Assert-Equal 'success' $m.ended 'ended'
Assert-Equal $false $m.is_error 'is_error'
Assert-Equal 1 $m.permission_denials 'permission_denials'

$spec = Get-TaskSpec -Path "$PSScriptRoot/fixtures/sample-task.md"
Assert-Equal 'T9' $spec.id 'task id'
Assert-Equal 'Sample task' $spec.title 'task title'
Assert-Equal 2 $spec.scope.sliced.Count 'scope.sliced count'
Assert-Equal 1 $spec.scope.layered.Count 'scope.layered count'
Assert-Equal "Do the thing.`nThen do the other thing." $spec.prompt 'prompt body'

Assert-Equal '^src/Orders\.Api/Features/Ship[^/]*/.*$' (ConvertTo-GlobRegex 'src/Orders.Api/Features/Ship*/**') 'glob regex'
Assert-Equal $true (Test-PathInScope -Path 'src/Orders.Api/Features/ShipOrder/ShipOrderHandler.cs' -Globs $spec.scope.sliced) 'in scope'
Assert-Equal $true (Test-PathInScope -Path 'tests\Orders.SliceTests\ShipOrderTests.cs' -Globs $spec.scope.sliced) 'in scope, backslashes'
Assert-Equal $false (Test-PathInScope -Path 'src/Orders.Api/Domain/Order.cs' -Globs $spec.scope.sliced) 'out of scope'

$trx = Join-Path ([IO.Path]::GetTempPath()) 'parse-events-sample.trx'
@'
<?xml version="1.0" encoding="utf-8"?>
<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <ResultSummary outcome="Failed"><Counters total="13" executed="13" passed="12" failed="1" /></ResultSummary>
</TestRun>
'@ | Set-Content -Path $trx -Encoding utf8
$t = Read-TrxSummary -Path $trx
Assert-Equal 13 $t.total 'trx total'
Assert-Equal 12 $t.passed 'trx passed'
Assert-Equal 1 $t.failed 'trx failed'
Remove-Item $trx

$jscpd = Join-Path ([IO.Path]::GetTempPath()) 'parse-events-sample-jscpd.json'
'{"statistics":{"total":{"lines":100,"sources":5,"clones":2,"duplicatedLines":12,"percentage":12.0}}}' | Set-Content -Path $jscpd -Encoding utf8
$j = Read-JscpdSummary -Path $jscpd
Assert-Equal 5 $j.sources 'jscpd sources'
Assert-Equal 2 $j.clones 'jscpd clones'
Assert-Equal 12 $j.percentage 'jscpd percentage'
Remove-Item $jscpd
$missing = Read-JscpdSummary -Path (Join-Path ([IO.Path]::GetTempPath()) 'does-not-exist-jscpd.json')
Assert-Equal 0 $missing.sources 'jscpd missing report -> sources 0'

if ($failures -gt 0) { Write-Host "$failures assertion(s) failed"; exit 1 }
Write-Host 'Test-ParseEvents: all assertions passed'
