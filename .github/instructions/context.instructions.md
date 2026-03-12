---
applyTo: "**/*"
---

# Context instructions (applies to all files)

Purpose
- Quickly capture short, actionable lessons when code generation and review misalign.

Scope
- Applies to all contributors and automated agents.

When to apply
- Whenever review findings, validation failures, or reviewer feedback differ from generated code, or a recurring mistake appears.

Process (short)
1. Detect
   - One-line symptom: where (file/PR) and why it's a problem.

2. Review and verify
   - Always perform a focused review of the generated change and run the repository's existing validation commands before finalizing changes.
   - If the repository does not define dedicated automation, do a manual diff review plus at least one concrete targeted verification step for the change (for example, `git diff --check` for docs/config edits or a load-time smoke check for Neovim Lua changes).

3. Record
   - Add a short entry under .github/instructions/ including:
     - What: one-line summary
     - Where: file paths and PR number
     - Diff/fix: paste the failing diff or the minimal fix
     - Why: brief explanation of the root cause
     - Verification: one-line check to confirm the fix
   - Keep entries concise and code-linked.

4. Update PR/commit
   - Append the diff/fix and a short description to the PR body or commit message and reference the instruction entry.

5. Automated agents
   - If an automated agent generates code, it must review the result and verify it with the repository's available validation steps before finalizing changes.
   - If generated code produces errors (syntax/runtime/test failures) or requires iterative guidance (e.g., re-prompting, partial fixes) to reach a correct result, record:
     - Error: concise error messages or failing test names/log snippets
     - Attempts: prompts or steps used to guide/fix the code
     - Final diff/fix: the minimal changes that fixed the problem
     - Verification: how the fix was validated (tests run, lint, manual check)
   - Append the diff/fix and the above details to the instruction entry and re-run the relevant review and validation steps; do not merge until verification passes.
   - Store a concise memory/fact for future automation when relevant.

Commit/branch conventions
- Use focused branch names (e.g. fix/context-...), conventional commits (docs/context, fix(context): ...), and include the Co-authored-by trailer when applicable.

Verification
- Re-run the relevant review and validation steps, confirm the generated code matches the reviewed code, and mark the instruction entry verified.

Tone
- Short, example-driven, and anchored to file paths. Do not open issues by default — record and verify first.

These instructions exist to reduce repeated review failures by ensuring diffs, fixes, and explanations are preserved and discoverable.
