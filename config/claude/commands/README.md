# Commands Reference

This directory contains slash commands available in OpenCode.

## Available Commands

| Command | Description |
|---------|-------------|
| `/todo` | Manage todo lists for task tracking |
| `/generate-tests` | Generate test files for components and functions |
| `/refactor-code` | Intelligent refactoring with safety checks |
| `/release <version>` | Create a new Git Flow release branch |

## Usage

Commands are invoked with the `/` prefix:

```
/todo add "Implement login feature"
/generate-tests src/components/Button.tsx
/refactor-code --target=src/utils/
/release 1.2.3
```

## Command Format

Commands are defined in `.md` files with YAML frontmatter:

```yaml
---
name: command-name
description: What this command does
---
```
