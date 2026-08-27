@echo off
rem Stand-in for the Claude Code CLI: `run.ps1 -ClaudeCommand experiment/stub/claude.cmd` drives the whole
rem harness without spending anything. A .cmd, not a .ps1, so the runner starts a real child process with a
rem real stdin, exactly as it starts `claude`.
pwsh -NoProfile -File "%~dp0claude-stub.ps1"
exit /b %ERRORLEVEL%
