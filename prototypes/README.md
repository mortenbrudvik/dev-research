# Prototypes

Runnable projects that the research in [`docs/`](../docs/) leads to. One folder per topic, mirroring the docs slug, and one folder per prototype inside it:

    prototypes/<topic>/<name>/

`<name>` is a short kebab-case description of what the prototype demonstrates, for example `langgraph-writer-critic`. Each prototype is self-contained: its own `README.md` (what it demonstrates, how to run it, which guide section it illustrates), its own tooling and lockfile, its own language. C#, TypeScript, and Python side by side is expected. There is no root-level build or workspace; a pnpm workspace or a solution file is added only when several same-stack prototypes make it worth it.

The root `.gitignore` ignores `bin/`, `obj/`, `dist/`, `node_modules/`, `.venv/`, and `.env` / `.env.*` (except `.env.example`) at any depth. If a prototype needs one of those tracked — a Node CLI with `bin/cli.js`, a deliberately committed `dist/` demo — add a nested `.gitignore` inside the prototype containing, for example, `!bin/`. The same file is where a prototype ignores anything unusual it produces.

Topic folders are created together with their first prototype, and each prototype is linked from its topic's landing page under `docs/<topic>/index.md`.
