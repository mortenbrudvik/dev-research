#requires -Version 5.1
<#
.SYNOPSIS
  Serve the Dev Research wiki locally with live reload.
.DESCRIPTION
  Creates .venv if missing, installs requirements.txt when it has changed, then
  runs `mkdocs serve --open` at http://127.0.0.1:8000. Extra arguments are passed
  through to mkdocs serve (prefix with `--` so PowerShell does not parse them).
.EXAMPLE
  .\serve.ps1
  .\serve.ps1 -- -a 127.0.0.1:8080
#>
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-Location -LiteralPath $PSScriptRoot

function Find-Python {
    $py = Get-Command -Name py -ErrorAction SilentlyContinue
    if ($py) {
        return @{ Exe = $py.Source; PrefixArgs = @('-3') }
    }
    $python = Get-Command -Name python -ErrorAction SilentlyContinue
    if ($python) {
        return @{ Exe = $python.Source; PrefixArgs = @() }
    }
    throw 'Python 3 is required to serve the wiki. Install it from https://www.python.org/downloads/ and retry.'
}

$venvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$requirements = Join-Path $PSScriptRoot 'requirements.txt'
$stamp = Join-Path $PSScriptRoot '.venv\.requirements-stamp'

if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host 'Creating .venv ...'
    $python = Find-Python
    $venvArgs = $python.PrefixArgs + @('-m', 'venv', '.venv')
    & $python.Exe @venvArgs
    if ($LASTEXITCODE) { throw "Failed to create .venv (exit $LASTEXITCODE)." }
}

$reqTime = (Get-Item -LiteralPath $requirements).LastWriteTimeUtc
$stampTime = if (Test-Path -LiteralPath $stamp) {
    (Get-Item -LiteralPath $stamp).LastWriteTimeUtc
} else {
    [datetime]::MinValue
}
if ($reqTime -gt $stampTime) {
    Write-Host 'Installing site dependencies ...'
    & $venvPython -m pip install -r $requirements
    if ($LASTEXITCODE) { throw "pip install failed (exit $LASTEXITCODE)." }
    $reqTime.ToString('o') | Set-Content -LiteralPath $stamp -Encoding ascii
}

$serveArgs = @('-m', 'mkdocs', 'serve', '--open') + $args

Write-Host 'Serving wiki at http://127.0.0.1:8000 (Ctrl+C to stop) ...'
& $venvPython @serveArgs
exit $LASTEXITCODE
