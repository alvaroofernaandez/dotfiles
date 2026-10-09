# Unit changelog

Each unit has its own version ([SemVer](https://semver.org)), declared in `{{manifest}}` and repeated in its guide. This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) with one section per unit. The project version (root `CHANGELOG.md`) is independent.

When to bump: the unit's source or a shared module it imports changes. Fix with no visible change = patch; compatible new feature = minor; anything a user relied on changes or disappears = major.

## [Unreleased]

### Added

- Manifest and this changelog. No build output changes.

## {{unit-id}}

{{One line: what the unit is.}} Guide: [`{{doc}}`]({{relative-path-to-doc}}).

### [1.0.0] - {{YYYY-MM-DD}}

#### Added

- First published version, with {{project}} {{since}}.
