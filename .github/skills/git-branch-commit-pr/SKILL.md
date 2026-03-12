---
name: git-branch-commit-pr
description: Automates the workflow of creating a feature branch, committing changes, and opening a PR. Use this when asked to create a branch, make changes, commit, and open a pull request for Lua code improvements or fixes.
---

# Lua Code Change Workflow Skill

When tasked with creating a branch, committing code changes, and opening a pull request for this repository, follow this workflow:

## Workflow Steps

1. **Create Feature Branch**
   - Create a new branch with a descriptive name based on the task.
   - Use the format: `feature/{description}`, `fix/{description}`, or `chore/{description}` as appropriate.

2. **Make Code Changes**
   - Make precise, task-focused changes only.
   - For Lua files, follow `.github/instructions/lua.instructions.md`.
   - Do not limit updates to `.lua` files when the task also requires related documentation or configuration changes.
   - Keep user-facing behavior and documentation in sync. In this repository, changes to public options, keymaps, or API behavior may also require updates to `README.md` and `doc/aiwaku.nvim.txt`.

3. **Review Code Changes**
   - Validate that the code actually works before committing.
   - Run the repository's existing validation steps when they exist. If there is no dedicated test or lint command, perform the most relevant available verification and state what you checked.
   - Run a review pass before finalizing changes and address any substantive issues found.

4. **Commit Changes**
   - Before creating the commit, confirm the intended commit message format with the user if it has not already been specified.
   - Use a conventional commit message in the format `type(scope): description`.
   - Keep the commit focused to one logical change.
   - Include the required trailer:
     - `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`

5. **Open Pull Request**
   - Do not push changes or open a pull request automatically without first confirming the PR title/description format with the user if it has not already been specified.
   - Use the GitHub MCP server or GitHub CLI to open the pull request after confirmation.lua
   - Include a meaningful title and a clearly structured description that explains what changed and why.
   - Link related issues when applicable.

## Tools to Use

- Git commands for local branch, status, diff, add, commit, and push operations
- GitHub MCP Server tools or GitHub CLI for pull request creation
- Repository instructions in `.github/copilot-instructions.md` and `.github/instructions/lua.instructions.md`
- Always verify changes before committing or opening a pull request
