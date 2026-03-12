---
applyTo: "**/*"
---

# Context instructions (applies to all files)

Purpose
- Quickly capture short, actionable lessons when code generation and review misalign.

Scope
- Applies to all contributors and automated agents.

When to apply
- Whenever /review output or reviewer feedback differs from generated code, or a recurring mistake appears.

Process (short)
1. Detect
   - One-line symptom: where (file/PR) and why it's a problem.

2. Run /review
   - Always run the /review command and verify code quality before finalizing changes.

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
   - If an automated agent generates code, it must run /review and verify the result before finalizing changes.
   - If generated code produces errors (syntax/runtime/test failures) or requires iterative guidance (e.g., re-prompting, partial fixes) to reach a correct result, record:
     - Error: concise error messages or failing test names/log snippets
     - Attempts: prompts or steps used to guide/fix the code
     - Final diff/fix: the minimal changes that fixed the problem
     - Verification: how the fix was validated (tests run, lint, manual check)
   - Append the diff/fix and the above details to the instruction entry and re-run /review; do not merge until /review passes.
   - Store a concise memory/fact for future automation when relevant.

Commit/branch conventions
- Use focused branch names (e.g. fix/context-...), conventional commits (docs/context, fix(context): ...), and include the Co-authored-by trailer when applicable.

Verification
- Re-run /review and confirm the generated code matches the reviewed code; mark the instruction entry verified.

Tone
- Short, example-driven, and anchored to file paths. Do not open issues by default — record and verify first.

These instructions exist to reduce repeated review failures by ensuring diffs, fixes, and explanations are preserved and discoverable.
