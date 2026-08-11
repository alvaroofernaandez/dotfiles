---
name: react-best-practices
description: Comprehensive React and Next.js performance optimization guide with 40+ rules for eliminating waterfalls, optimizing bundles, and improving rendering.
version: 1.0.0
author: example-org Team
triggers:
  - optimize react
  - improve performance
  - fix waterfall
  - bundle optimization
  - react performance
  - next.js optimization
---

# React Best Practices Skill

## When to Use

Use this skill when:
- Optimizing React applications
- Reviewing performance
- Refactoring components
- Building new React features

## Core Principles

### 1. Eliminate Waterfalls

**Bad**: Sequential data fetching
```tsx
// Waterfall - don't do this
const user = await fetchUser();
const posts = await fetchPosts(user.id); // waits for user
const comments = await fetchComments(posts[0].id); // waits for posts
```

**Good**: Parallel data fetching
```tsx
// Parallel - correct approach
const [user, posts] = await Promise.all([
  fetchUser(),
  fetchPosts()
]);
```

### 2. Optimize Rendering

- Use `React.memo()` for expensive components
- Use `useMemo()` for expensive calculations
- Use `useCallback()` for stable function references
- Split large components

### 3. Bundle Optimization

- Code split with dynamic imports
- Tree-shake unused exports
- Analyze bundle size regularly
- Lazy load below-the-fold content

### 4. Next.js Specific

- Use App Router for new projects
- Leverage Server Components
- Use Image component for optimization
- Implement proper caching strategies

## Rules Reference

1. **Data Fetching**: Parallel > Sequential
2. **State Management**: Lift state only when necessary
3. **Effects**: Minimize dependencies
4. **Context**: Split contexts to prevent unnecessary re-renders
5. **Lists**: Always use keys, virtualize long lists
6. **Images**: Optimize, lazy load, use correct formats
7. **Fonts**: Use next/font for optimization
8. **Scripts**: Use next/script for third-party scripts

## Anti-Patterns

- DON'T fetch data in useEffect when possible
- DON'T ignore React DevTools Profiler
- DON'T over-optimize prematurely
- DON'T use useMemo for everything
