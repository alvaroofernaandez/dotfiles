---
name: ui-design-system
description: UI design system toolkit for Senior UI Designer including design token generation, component documentation, responsive design calculations, and developer handoff tools. Use for creating design systems, maintaining visual consistency, and facilitating design-dev collaboration.
version: 1.0.0
author: example-org Team
triggers:
  - design system
  - design tokens
  - component library
  - ui kit
  - style guide
  - design documentation
---

# UI Design System Skill

## When to Use

Use this skill for:
- Creating design systems
- Maintaining visual consistency
- Facilitating design-dev collaboration
- Documenting components

## Capabilities

### Design Tokens
- Color palettes (primary, secondary, semantic)
- Typography scales
- Spacing systems
- Border radius
- Shadows and elevation
- Breakpoints

### Component Documentation
- Props tables
- Usage examples
- Do/Don't guidelines
- Accessibility notes
- Variant definitions

### Responsive Design
- Breakpoint calculations
- Fluid typography
- Container queries
- Grid systems

### Developer Handoff
- CSS variable generation
- Component specifications
- Animation definitions
- Asset exports

## Design Token Structure

```
tokens/
├── colors/
│   ├── primary.json
│   ├── secondary.json
│   └── semantic.json
├── typography/
│   ├── font-families.json
│   ├── font-sizes.json
│   └── font-weights.json
├── spacing/
│   └── scale.json
├── effects/
│   ├── shadows.json
│   └── animations.json
└── breakpoints/
    └── responsive.json
```

## Process

1. **Audit Existing UI**
   - Inventory current components
   - Identify inconsistencies
   - Document patterns

2. **Define Tokens**
   - Color palette
   - Typography scale
   - Spacing system
   - Other foundations

3. **Build Components**
   - Design in Figma
   - Document specifications
   - Create code components

4. **Document System**
   - Usage guidelines
   - Best practices
   - Accessibility requirements

5. **Maintain & Evolve**
   - Version control
   - Change logs
   - Deprecation process

## Output

- Design token files
- Component library
- Documentation site
- Figma library

## Anti-Patterns

- DON'T skip accessibility
- DON'T create one-off exceptions
- DON'T ignore platform constraints
- DON'T forget to version
