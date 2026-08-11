---
name: refactor-code
description: Intelligent code refactoring with LSP, AST analysis, and safety verification
---

# /refactor-code Command

Safely refactor code using intelligent analysis and verification.

## Usage

```
/refactor-code [options]
```

## Options

- `--target=<path>` - Target file or directory (required if no selection)
- `--mode=rename|extract|inline|reorganize` - Refactoring type
- `--name=<new-name>` - New name for rename operations
- `--dry-run` - Preview changes without applying
- `--verify` - Run tests after refactoring

## Refactoring Modes

### `rename`
Rename symbols across entire codebase.

```
/refactor-code --mode=rename --target=src/utils/oldName.ts --name=newName
```

### `extract`
Extract code into functions, components, or modules.

```
/refactor-code --mode=extract --target=src/components/LargeComponent.tsx
```

### `inline`
Inline redundant abstractions.

```
/refactor-code --mode=inline --target=src/utils/unnecessaryWrapper.ts
```

### `reorganize`
Reorganize imports, exports, or file structure.

```
/refactor-code --mode=reorganize --target=src/services/
```

## Safety Features

- LSP-based rename validation
- AST-aware replacements
- TypeScript type checking
- Test verification (with --verify)
- Dry-run preview

## Workflow

1. **Analyze**: Parse code structure
2. **Plan**: Determine refactoring steps
3. **Preview** (dry-run): Show changes
4. **Execute**: Apply changes
5. **Verify**: Check for errors

## Examples

```bash
# Rename a function across codebase
/refactor-code --mode=rename --target=src/utils/helpers.ts --name=utilities --dry-run

# Extract component from large file
/refactor-code --mode=extract --target=src/pages/Dashboard.tsx

# Reorganize service layer
/refactor-code --mode=reorganize --target=src/services/ --verify

# Preview before applying
/refactor-code --target=src/components/ --dry-run
```

## Best Practices

- Always use `--dry-run` first for large changes
- Run with `--verify` to catch regressions
- Commit before major refactorings
- Review changes before committing
