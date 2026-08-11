---
name: todo
description: Manage todo lists for task tracking with CRUD operations
---

# /todo Command

Manage project todos directly from OpenCode chat.

## Usage

```
/todo add "Implement login feature" --priority=high
/todo list
/todo complete 1
/todo remove 2
/todo clear
```

## Subcommands

### `add <description>`
Add a new todo item.

Options:
- `--priority=high|medium|low` - Set priority (default: medium)
- `--tag=<tag>` - Add category tag

### `list`
Show all pending todos.

Options:
- `--all` - Show completed todos too
- `--filter=<tag>` - Filter by tag

### `complete <id>`
Mark a todo as completed.

### `remove <id>`
Remove a todo item permanently.

### `clear`
Remove all completed todos.

## Examples

```
/todo add "Fix navigation bug" --priority=high --tag=bug
/todo add "Update documentation" --priority=low --tag=docs
/todo list --all
/todo complete 3
```

## Tips

- Use descriptive task names
- Set realistic priorities
- Review and clear completed todos regularly
- Tag todos for better organization
