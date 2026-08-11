---
name: file-organizer
description: Intelligently organizes files and folders by understanding context, finding duplicates, and suggesting better organizational structures.
version: 1.0.0
author: example-org Team
triggers:
  - organize files
  - clean up
  - remove duplicates
  - restructure project
  - organize directory
  - cleanup
---

# File Organizer Skill

## When to Use

Use this skill when the user wants to:
- Clean up directories
- Organize downloads
- Remove duplicates
- Restructure projects
- Improve file organization

## Capabilities

1. **Context Understanding**
   - Analyze file contents to understand purpose
   - Group related files together
   - Identify orphaned/unused files

2. **Duplicate Detection**
   - Find identical files by content hash
   - Find similar files by name/content
   - Suggest consolidation strategies

3. **Structure Recommendations**
   - Suggest better organizational patterns
   - Follow industry conventions
   - Maintain project consistency

## Process

1. **Analyze Current State**
   - Map existing structure
   - Identify patterns and anti-patterns
   - Count files by type/category

2. **Detect Issues**
   - Find duplicates
   - Identify orphaned files
   - Spot inconsistencies

3. **Propose Solution**
   - Recommend new structure
   - Explain rationale
   - Get user approval

4. **Execute (with permission)**
   - Move files safely
   - Create backup if needed
   - Update references

## Anti-Patterns

- DON'T delete without confirmation
- DON'T move files that are actively referenced
- DON'T break existing imports/paths without updating them
- DON'T reorganize without understanding project conventions
