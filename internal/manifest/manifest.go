// Package manifest reads install.manifest, the single source of truth for
// what this repository installs and where.
//
// install.sh parses the same file in bash. Neither implementation owns the
// list; tests/manifest.test.sh fails the build if the two ever disagree about
// what gets installed.
package manifest

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"
)

// Platform says where a group applies.
type Platform int

const (
	// PlatformUnix is macOS and Linux — and Windows only by way of WSL.
	PlatformUnix Platform = iota
	// PlatformAll additionally covers Windows natively.
	PlatformAll
)

func (p Platform) String() string {
	if p == PlatformAll {
		return "all"
	}
	return "unix"
}

// Entry is one thing to install: a path in the repo, and where it goes
// relative to the user's home directory.
type Entry struct {
	Source string
	Dest   string
}

// Group is a set of entries the user can choose to install or skip.
type Group struct {
	ID        string
	Label     string
	Detail    string
	Platforms Platform

	Entries []Entry

	// FanoutSource names a directory whose every child is installed into each
	// of FanoutDests. Skills work this way so that adding one needs no manifest
	// edit at all.
	FanoutSource string
	FanoutDests  []string
}

// AppliesTo reports whether the group should be offered on the given GOOS.
func (g Group) AppliesTo(goos string) bool {
	if g.Platforms == PlatformAll {
		return true
	}
	return goos != "windows"
}

// Manifest is the parsed file, with groups in the order they appear. Order is
// preserved deliberately: the TUI renders them in file order, and a map would
// shuffle the list between runs.
type Manifest struct {
	Groups []Group
}

// Load reads and parses the manifest at path.
func Load(path string) (*Manifest, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("manifest: %w", err)
	}
	defer f.Close()
	return Parse(f)
}

// Parse reads a manifest from r.
func Parse(r io.Reader) (*Manifest, error) {
	m := &Manifest{}
	var cur *Group
	// Tracks whether the open group named its platform. Defaulting silently
	// would install a Unix-only group on Windows, which is exactly the bug the
	// platform key exists to prevent.
	seenPlatforms := false

	flush := func() error {
		if cur == nil {
			return nil
		}
		if !seenPlatforms {
			return fmt.Errorf("manifest: group %q does not declare platforms", cur.ID)
		}
		m.Groups = append(m.Groups, *cur)
		return nil
	}

	sc := bufio.NewScanner(r)
	for line := 1; sc.Scan(); line++ {
		text := sc.Text()
		// Strip comments first: a trailing comment on an entry line would
		// otherwise be read as part of the destination.
		if i := strings.IndexByte(text, '#'); i >= 0 {
			text = text[:i]
		}
		text = strings.TrimSpace(text)
		if text == "" {
			continue
		}

		if strings.HasPrefix(text, "[") && strings.HasSuffix(text, "]") {
			if err := flush(); err != nil {
				return nil, err
			}
			cur = &Group{ID: strings.Trim(text, "[]")}
			seenPlatforms = false
			continue
		}

		if cur == nil {
			return nil, fmt.Errorf("manifest: line %d: entry outside any group: %q", line, text)
		}

		if key, value, ok := strings.Cut(text, "="); ok {
			key = strings.TrimSpace(key)
			value = strings.TrimSpace(value)
			switch key {
			case "label":
				cur.Label = value
			case "detail":
				cur.Detail = value
			case "platforms":
				switch value {
				case "unix":
					cur.Platforms = PlatformUnix
				case "all":
					cur.Platforms = PlatformAll
				default:
					return nil, fmt.Errorf("manifest: line %d: unknown platform %q", line, value)
				}
				seenPlatforms = true
			case "fanout-source":
				cur.FanoutSource = value
			case "fanout-dests":
				cur.FanoutDests = strings.Fields(value)
			default:
				return nil, fmt.Errorf("manifest: line %d: unknown key %q", line, key)
			}
			continue
		}

		fields := strings.Fields(text)
		if len(fields) != 2 {
			return nil, fmt.Errorf("manifest: line %d: expected \"<source> <dest>\", got %q", line, text)
		}
		cur.Entries = append(cur.Entries, Entry{Source: fields[0], Dest: fields[1]})
	}
	if err := sc.Err(); err != nil {
		return nil, fmt.Errorf("manifest: %w", err)
	}
	if err := flush(); err != nil {
		return nil, err
	}
	return m, nil
}
