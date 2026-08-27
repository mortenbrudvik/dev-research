#!/usr/bin/env sh
# Guardrail gate for Claude Code.
#   PostToolUse (Edit|Write of a .cs/.csproj/.props file): architecture tests.
#   Stop, or an event that could not be parsed:            architecture tests, then the behaviour tests.
# Exit 2 (blocking) with the failure text on stderr; a missing CLAUDE_PROJECT_DIR exits 1 (non-blocking: the
# user's environment, not the agent's change). Appends one line per invocation to .gate.log:
#   <utc time> <event> exit=0 | exit=2 <project> build|test | skipped <reason>
cd "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR is not set}" || exit 2
input=$(cat)
# The hook input is JSON on stdin; tolerate both compact and pretty-printed forms.
event=$(printf '%s' "$input" | grep -o '"hook_event_name": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
event=${event:-unknown}
stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

if printf '%s' "$input" | grep -q '"stop_hook_active": *true'; then
  echo "$(stamp) $event skipped stop_hook_active" >> .gate.log
  exit 0
fi

if [ "$event" = "PostToolUse" ]; then
  file=$(printf '%s' "$input" | grep -o '"file_path": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  case "$file" in
    ""|*.cs|*.csproj|*.props) ;;   # an unparsed path fails closed: the tests run
    *) echo "$(stamp) $event skipped non-code file" >> .gate.log; exit 0 ;;
  esac
  projects="tests/Orders.ArchitectureTests"
else
  projects="tests/Orders.ArchitectureTests tests/Orders.SliceTests"
fi

for project in $projects; do
  # -v q silences MSBuild; the console logger at normal verbosity keeps the assertion block (Expected/Actual);
  # the Logging override keeps EF Core's SQL out of the output.
  if ! out=$(Logging__LogLevel__Default=Warning dotnet test "$project" --nologo -v q --logger "console;verbosity=normal" 2>&1); then
    # No "Test run for" line means the tests never ran: a build or restore failure (CS, xUnit analyzer, NU, MSB),
    # i.e. a half-written change, not a rule violation.
    reason=test
    if ! printf '%s' "$out" | grep -q '^Test run for '; then reason=build; fi
    echo "$(stamp) $event exit=2 $project $reason" >> .gate.log
    # Drop stack frames, per-test "Passed" lines and leftover noise so the failure messages survive the cut.
    printf '%s\n' "$out" | grep -v -e '^ *at ' -e '^ *Passed ' -e '^info: ' -e '^ *Stack Trace:$' -e '^--- End of stack trace' | tail -80 >&2
    exit 2
  fi
done

echo "$(stamp) $event exit=0" >> .gate.log
exit 0
