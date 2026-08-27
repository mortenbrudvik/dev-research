#!/usr/bin/env sh
# Guardrail gate for Claude Code.
#   PostToolUse (Edit|Write): architecture tests.
#   Stop:                     architecture tests, then the behaviour tests.
# Exit 2 (blocking) with the failure text on stderr. Appends one line per invocation to .gate.log.
cd "$CLAUDE_PROJECT_DIR" || exit 2
input=$(cat)
# The hook input is JSON on stdin; tolerate both compact and pretty-printed forms.
event=$(printf '%s' "$input" | grep -o '"hook_event_name": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

if printf '%s' "$input" | grep -q '"stop_hook_active": *true'; then
  echo "$(stamp) $event skipped stop_hook_active" >> .gate.log
  exit 0
fi

projects="tests/Orders.ArchitectureTests"
if [ "$event" = "Stop" ]; then
  projects="$projects tests/Orders.SliceTests"
fi

for project in $projects; do
  if ! out=$(dotnet test "$project" --nologo -v q 2>&1); then
    echo "$(stamp) $event exit=2 $project" >> .gate.log
    printf '%s\n' "$out" | grep -v '^ *at ' | tail -60 >&2   # drop stack frames so the failure messages survive the cut
    exit 2
  fi
done

echo "$(stamp) $event exit=0" >> .gate.log
exit 0
