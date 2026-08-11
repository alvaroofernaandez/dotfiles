---
name: release
description: Create a new Git Flow release branch with version bumping and changelog
---

# /release Command

Create a new release following Git Flow conventions.

## Usage

```
/release <version> [options]
```

## Arguments

- `<version>` - Version number (required)
  - Format: `MAJOR.MINOR.PATCH` (e.g., `1.2.3`)
  - Or: `major`, `minor`, `patch` for automatic bump

## Options

- `--from=<branch>` - Source branch (default: develop)
- `--message=<msg>` - Custom release message
- `--no-changelog` - Skip changelog generation
- `--draft` - Create as draft release
- `--dry-run` - Preview without executing

## Git Flow Process

1. **Create release branch** from develop
2. **Bump version** in package.json
3. **Update changelog** with commits since last release
4. **Commit changes** to release branch
5. **Create PR** for review (optional)

## Examples

```bash
# Release specific version
/release 1.2.3

# Auto-bump minor version
/release minor

# Custom message
/release 2.0.0 --message="Major API redesign"

# Preview only
/release 1.3.0 --dry-run

# Skip changelog
/release 1.2.4 --no-changelog
```

## Version Bumping

| Type | Effect | Example |
|------|--------|---------|
| `major` | Breaking changes | 1.2.3 → 2.0.0 |
| `minor` | New features | 1.2.3 → 1.3.0 |
| `patch` | Bug fixes | 1.2.3 → 1.2.4 |

## Changelog Generation

Automatically includes:
- Commit messages since last tag
- PR titles and descriptions
- Issue references
- Breaking changes section

## Post-Release

After PR merge:
1. Release branch merges to `main`
2. Tag created: `v1.2.3`
3. `main` merges back to `develop`
4. Release notes published

## Requirements

- Must be on `develop` branch
- Working directory must be clean
- All changes committed
- No unmerged release branches
