---
name: git-branch-commit-pr
description: Automates the workflow of creating a feature branch, committing changes, and opening a PR. Use this when asked to create a branch, make changes, commit, and open a pull request for Lua code improvements or fixes.
---

# Lua Code Change Workflow Skill

When tasked with creating a branch, committing code changes, and opening a pull request for Lua files, follow this workflow:

## Workflow Steps

1. **Create Feature Branch**
   - Create a new branch with a descriptive name based on the task
   - Use the format: `feature/{description}` or `fix/{description}`

2. **Make Code Changes**
   - Only modify `.lua` files unless explicitly instructed otherwise
   - Follow the Lua Code with Review Standards in `.github/instructions/lua.instructions.md`
   - Follow Lua best practices:
     - Use local variables by default
     - 2-space indentation
     - snake_case naming conventions
     - Include comments for complex logic

3. **Review Code Changes**
   - Validate the Code actually works
   - Follow the Lua Code with Review Standards in `.github/instructions/lua.instructions.md`

3. **Commit Changes**
   - Write clear, descriptive commit messages
   - Format: `feat(lua): description` or `fix(lua): description`
   - Include details about what changed and why

4. **Open Pull Request**
   - Use the GitHub MCP server to create the PR
   - Include a meaningful title and description
   - Link any related issues if applicable

## Tools to Use

- GitHub CLI commands for git operations
- GitHub MCP Server tools for creating PRs and managing GitHub resources
- Always verify changes before committing
