---
name: generate-tests
description: Generate comprehensive test files for components and functions using Vitest
---

# /generate-tests Command

Generate test files automatically for React components and TypeScript functions.

## Usage

```
/generate-tests <file-path> [options]
```

## Arguments

- `<file-path>` - Path to component or function file (required)

## Options

- `--type=component|hook|util|api` - Force test type (auto-detected if not specified)
- `--coverage` - Include coverage-focused tests
- `--e2e` - Generate Playwright E2E test instead of unit test
- `--dry-run` - Preview generated test without writing file

## Examples

```bash
# Generate test for a component
/generate-tests src/components/Button.tsx

# Generate test for a hook
/generate-tests src/hooks/useAuth.ts

# Generate E2E test
/generate-tests src/app/login/page.tsx --e2e

# Preview before generating
/generate-tests src/utils/helpers.ts --dry-run
```

## Generated Test Structure

### Component Tests
- Rendering assertions
- Props validation
- User interaction tests
- Accessibility checks
- Snapshot tests (optional)

### Hook Tests
- Initial state verification
- State update tests
- Side effect testing
- Cleanup verification

### Utility Tests
- Input/output assertions
- Edge case coverage
- Error handling
- Performance benchmarks

## Conventions

- Tests saved as `__tests__/<filename>.test.tsx` alongside source
- Uses Vitest + React Testing Library
- Follows existing test patterns in codebase
- Includes descriptive test names
