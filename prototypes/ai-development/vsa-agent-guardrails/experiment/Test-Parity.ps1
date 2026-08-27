#requires -Version 7
# Run: pwsh experiment/Test-Parity.ps1   (exit code 0 = the copies behave identically)
param([int]$SlicedPort = 5101, [int]$LayeredPort = 5102)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Path $PSScriptRoot -Parent

function Start-Api([string]$copyName, [int]$port) {
    $db = Join-Path $env:TEMP "parity-$copyName-$([guid]::NewGuid().ToString('N')).db"
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'dotnet'
    $psi.Arguments = "run --project src/Orders.Api --no-launch-profile --urls http://localhost:$port"
    $psi.WorkingDirectory = Join-Path $root $copyName
    $psi.Environment['ConnectionStrings__Orders'] = "Data Source=$db"
    $psi.Environment['ASPNETCORE_ENVIRONMENT'] = 'Development'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    # Drain both pipes in the background: a child that fills a redirected pipe blocks on its next write.
    [void]$proc.StandardOutput.ReadToEndAsync()
    $stderr = $proc.StandardError.ReadToEndAsync()
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if ($proc.HasExited) { throw "$copyName exited early:`n$($stderr.Result)" }
        try {
            $r = Invoke-WebRequest -Uri "http://localhost:$port/orders" -SkipHttpErrorCheck -TimeoutSec 2
            if ($r.StatusCode -eq 200) { return [pscustomobject]@{ proc = $proc; db = $db } }
        }
        catch { }
    }
    throw "$copyName did not start on port $port within 120 s"
}

function Invoke-Scenario([int]$port) {
    $base = "http://localhost:$port"
    $steps = [System.Collections.Generic.List[object]]::new()
    # Invoke-WebRequest only decodes Content to a string for media types it knows are text;
    # application/problem+json is not on that list, so every 400/409 body arrives as byte[].
    $record = { param($name, $r)
        $body = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { $r.Content }
        $steps.Add([pscustomobject]@{ step = $name; status = $r.StatusCode; body = $body }) }

    $created = Invoke-WebRequest -Uri "$base/orders" -Method Post -ContentType 'application/json' -SkipHttpErrorCheck `
        -Body '{"customerId":"c1","lines":[{"sku":"S1","quantity":2,"unitPrice":9.5}]}'
    & $record 'create' $created
    $id = ($created.Content | ConvertFrom-Json).id
    & $record 'create-invalid' (Invoke-WebRequest -Uri "$base/orders" -Method Post -ContentType 'application/json' -SkipHttpErrorCheck -Body '{"customerId":"c1","lines":[]}')
    & $record 'get' (Invoke-WebRequest -Uri "$base/orders/$id" -SkipHttpErrorCheck)
    & $record 'get-unknown' (Invoke-WebRequest -Uri "$base/orders/$([guid]::Empty)" -SkipHttpErrorCheck)
    & $record 'list' (Invoke-WebRequest -Uri "$base/orders" -SkipHttpErrorCheck)
    & $record 'list-bad-status' (Invoke-WebRequest -Uri "$base/orders?status=Lost" -SkipHttpErrorCheck)
    & $record 'cancel' (Invoke-WebRequest -Uri "$base/orders/$id/cancel" -Method Post -SkipHttpErrorCheck)
    & $record 'cancel-again' (Invoke-WebRequest -Uri "$base/orders/$id/cancel" -Method Post -SkipHttpErrorCheck)
    & $record 'list-cancelled' (Invoke-WebRequest -Uri "$base/orders?status=Cancelled" -SkipHttpErrorCheck)
    return $steps
}

function Normalize([string]$s) {
    $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<guid>'
    $s = $s -replace '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})', '<time>'
    $s = $s -replace '"traceId":"[^"]*"', '"traceId":"<trace>"'
    return $s
}

# The test classes must be byte-for-byte the same apart from the namespace, the using block and the four DTO
# names Task 13 renames (sliced name -> layered name). Everything else — requests, assertions, method names — is
# compared as text, so a drifted assertion in one copy fails the check.
$DtoRenames = @{
    CreateOrderResponse = 'CreateOrderResult'
    GetOrderResponse    = 'OrderDto'
    CancelOrderResponse = 'CancelOrderResult'
    ListOrdersResponse  = 'OrderListDto'
}

function Get-NormalizedTests([string]$dir) {
    $result = @{}
    foreach ($f in Get-ChildItem -Path $dir -Filter '*Tests.cs') {
        $lines = [System.IO.File]::ReadAllLines($f.FullName) |     # ReadAllLines accepts LF and CRLF alike
            Where-Object { $_ -notmatch '^\s*(using |namespace )' } |
            ForEach-Object { $_.TrimEnd() }
        $text = ($lines -join "`n").Trim()
        foreach ($name in $DtoRenames.Keys) { $text = $text -replace "\b$name\b", $DtoRenames[$name] }
        $result[$f.Name] = $text
    }
    return $result
}

$failures = 0
$sliced = $null; $layered = $null
try {
    Write-Host 'Starting both APIs...'
    $sliced = Start-Api 'sliced' $SlicedPort
    $layered = Start-Api 'layered' $LayeredPort

    $a = Invoke-Scenario $SlicedPort
    $b = Invoke-Scenario $LayeredPort
    for ($i = 0; $i -lt $a.Count; $i++) {
        $sa = $a[$i]; $sb = $b[$i]
        $bodyA = Normalize $sa.body; $bodyB = Normalize $sb.body
        if ($sa.status -ne $sb.status -or $bodyA -ne $bodyB) {
            $failures++
            Write-Host "DIFF $($sa.step): sliced $($sa.status) $bodyA`n                 layered $($sb.status) $bodyB"
        }
        else { Write-Host "same $($sa.step) ($($sa.status))" }
    }

    $ta = Get-NormalizedTests (Join-Path $root 'sliced/tests/Orders.SliceTests')
    $tb = Get-NormalizedTests (Join-Path $root 'layered/tests/Orders.IntegrationTests')
    foreach ($file in (@($ta.Keys) + @($tb.Keys) | Sort-Object -Unique)) {
        if (-not ($ta.ContainsKey($file) -and $tb.ContainsKey($file))) {
            $failures++; Write-Host "DIFF tests $file exists in only one copy"; continue
        }
        if ($ta[$file] -ne $tb[$file]) {
            $failures++
            $la = $ta[$file] -split "`n"; $lb = $tb[$file] -split "`n"
            $n = 0
            while ($n -lt $la.Count -and $n -lt $lb.Count -and $la[$n] -eq $lb[$n]) { $n++ }
            $lineA = if ($n -lt $la.Count) { $la[$n] } else { '<end of file>' }
            $lineB = if ($n -lt $lb.Count) { $lb[$n] } else { '<end of file>' }
            Write-Host "DIFF tests $file at normalized line $($n + 1)`n  sliced:  $lineA`n  layered: $lineB"
        }
        else {
            $count = [regex]::Matches($ta[$file], 'public async Task \w+\(').Count
            Write-Host "same tests $file ($count methods)"
        }
    }
}
finally {
    foreach ($api in @($sliced, $layered)) {
        if ($null -ne $api) {
            if (-not $api.proc.HasExited) { $api.proc.Kill($true) }
            Remove-Item -Path "$($api.db)*" -ErrorAction SilentlyContinue   # the .db plus SQLite's -wal/-shm sidecars
        }
    }
}
if ($failures -gt 0) { Write-Host "$failures difference(s)"; exit 1 }
Write-Host 'Test-Parity: the copies behave identically'
