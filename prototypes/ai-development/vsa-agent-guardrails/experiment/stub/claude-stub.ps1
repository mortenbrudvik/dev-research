#requires -Version 7
# Stand-in for `claude -p --output-format stream-json --verbose`, used to exercise run.ps1 end to end for
# free. Like the real CLI it runs in the run directory, reads the prompt from stdin, changes the working
# tree and prints a transcript on stdout. Works in either copy: the behaviour test project decides the
# in-scope file. Two environment toggles let the runner's own verification steps reach its failure paths:
#   VSA_STUB_COMMIT=1  commit the change, so the runner must measure against the baseline commit, not HEAD
#   VSA_STUB_FAIL=1    print nothing at all and exit 3, so the runner must survive a missing transcript
$ErrorActionPreference = 'Stop'
$prompt = [Console]::In.ReadToEnd()
[Console]::Error.WriteLine("stub: $($prompt.Length) prompt characters, cwd $($PWD.Path)")
if ($env:VSA_STUB_FAIL -eq '1') { exit 3 }

$inScope = @('tests/Orders.SliceTests/HttpAssertions.cs', 'tests/Orders.IntegrationTests/HttpAssertions.cs') |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $inScope) { [Console]::Error.WriteLine('stub: no behaviour test project here'); exit 1 }
Add-Content -LiteralPath $inScope -Value '// stub edit'                     # one file inside the task's scope
Set-Content -LiteralPath 'stub-notes.txt' -Value 'deliberately out of scope'   # and one outside it
Set-Content -LiteralPath '.gate.log' -Value @(                              # the shape gate.sh writes
    '2026-01-01T00:00:00Z PostToolUse exit=2 Orders.Api build',
    '2026-01-01T00:00:01Z Stop exit=2 Orders.Api test',
    '2026-01-01T00:00:02Z Stop exit=0'
)
if ($env:VSA_STUB_COMMIT -eq '1') {
    & git add -A 2>&1 | Out-Null
    & git -c user.name=stub -c user.email=stub@example.invalid commit -q -m 'stub commit' 2>&1 | Out-Null
}

$toolUse = @(
    '{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"src/Orders.Api/Program.cs"}}'
    '{"type":"tool_use","id":"t2","name":"Read","input":{"file_path":"CLAUDE.md"}}'
    '{"type":"tool_use","id":"t3","name":"Read","input":{"file_path":"src/Orders.Api/Program.cs"}}'
    '{"type":"tool_use","id":"t4","name":"Grep","input":{"pattern":"Order"}}'
    '{"type":"tool_use","id":"t5","name":"Glob","input":{"pattern":"**/*.cs"}}'
    '{"type":"tool_use","id":"t6","name":"Edit","input":{"file_path":"' + $inScope + '"}}'
    '{"type":"tool_use","id":"t7","name":"Write","input":{"file_path":"stub-notes.txt"}}'
    '{"type":"tool_use","id":"t8","name":"Bash","input":{"command":"dotnet build"}}'
    '{"type":"tool_use","id":"t9","name":"Bash","input":{"command":"ls src"}}'
) -join ','
$transcript = @(
    '{"type":"system","subtype":"init","cwd":".","model":"stub-model"}'
    '{"type":"assistant","message":{"content":[' + $toolUse + ']}}'
    'a line that is not JSON, so that skipped_lines is exercised too'
    '{"type":"result","subtype":"success","total_cost_usd":0.1234,"num_turns":7,"duration_ms":12345,' +
    '"duration_api_ms":9876,"is_error":false,"terminal_reason":"completed","stop_reason":"end_turn",' +
    '"permission_denials":[],"usage":{"input_tokens":1200,"output_tokens":340,' +
    '"cache_read_input_tokens":50000,"cache_creation_input_tokens":2000},' +
    # Two obviously fake ids, the larger one second, so a row from the stub shows the sorted join the real
    # CLI's modelUsage keys produce.
    '"modelUsage":{"stub-model-fast":{"inputTokens":3},"stub-model":{"inputTokens":1200}}}'
)
foreach ($line in $transcript) { [Console]::Out.WriteLine($line) }
exit 0
