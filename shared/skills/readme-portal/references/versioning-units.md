# Versioning units

A unit is anything released or evolved independently inside one repo: plugins, packages, services, skills.

## Files

- `<unit-dir>/<manifest>.json`: `{schema_version, <list>: [{id, file, title, version, since, doc, ...}]}`. `version` is SemVer, `since` is the project version that first shipped it, `doc` is the unit guide. Add stack extras (for example `lib`: shared modules imported) only if a test can verify them.
- `<unit-dir>/CHANGELOG.md` (Keep a Changelog): one `## <id>` section per unit, `### [x.y.z] - date` entries, an `[Unreleased]` block on top. Template: `assets/UNIT-CHANGELOG.template.md`. Seed 1.0.0 as the first published state.
- A version line in each unit doc, for example ``**Unit:** `<id>` · **Version:** 1.0.0 · **Since:** Project 0.5.0``, plus a versions table in the units index doc.
- A bump rule in the maintainers doc: when a unit's source or a shared module it imports changes, in the same change bump the manifest, add the changelog entry, update the unit doc and the index table, and bump every unit importing a shared module. Patch = invisible fix, minor = compatible feature, major = something users rely on changes or disappears. A test cannot detect that code changed: the author owns the bump.

## Build check (mandatory)

Before creating the manifest in a unit dir, find what builds, packs or copies that dir (globs in build scripts, `files` in package.json, Dockerfile COPY, installers). If it would ship `*.json`, `CHANGELOG.md` or `README.md`, narrow the glob or exclude them, and add a test that builds into a temp dir and asserts the files are absent.
