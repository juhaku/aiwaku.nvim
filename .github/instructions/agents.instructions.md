---
applyTo: "AGENTS.md"
---

# AGENTS generation notes

- What: Include `lua/aiwaku/config.lua` in the repository layout section of `AGENTS.md`.
- Where: `AGENTS.md`; local uncommitted change, no PR number yet.
- Diff/fix: Added `- \`lua/aiwaku/config.lua\` — configuration defaults and command normalization logic.`
- Why: `config.lua` is part of the public initialization flow through `setup()` and owns defaults plus command normalization, so omitting it makes the repository map incomplete for future agents.
- Verification: Run `git diff --check` and review `git diff -- AGENTS.md .github/instructions/agents.instructions.md`.
