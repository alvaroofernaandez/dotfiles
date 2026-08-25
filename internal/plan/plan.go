// Package plan turns a manifest plus a target platform into the concrete list
// of things to install.
//
// It is deliberately pure: no file is created here, and nothing outside the
// fan-out directory is even read. That keeps the interesting decisions — which
// groups apply, how the fan-out expands, what the absolute paths are — testable
// without a filesystem, and leaves the executor in internal/install with
// nothing to decide.
package plan

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/alvaroofernaandez/dotfiles/internal/manifest"
)

// Action is a single install step, with both paths already absolute. The
// executor never re-resolves them: anything relative surviving to that point
// would be created relative to the process working directory.
type Action struct {
	Source string
	Dest   string
	// Label is the destination as the user knows it (~/.config/tmux), used in
	// the TUI so the display does not depend on where the repo happens to live.
	Label string
}

// Group is a manifest group with its actions resolved.
type Group struct {
	ID       string
	Label    string
	Detail   string
	Selected bool
	Actions  []Action
}

// Plan is everything the installer could do on this machine.
type Plan struct {
	Groups []Group
}

// Options configures Build. GOOS is a parameter rather than runtime.GOOS so
// the Windows and Linux paths are testable from a macOS machine.
type Options struct {
	Repo string
	Home string
	GOOS string
}

// Build resolves a manifest against a platform.
func Build(m *manifest.Manifest, opt Options) (*Plan, error) {
	p := &Plan{}

	for _, g := range m.Groups {
		if !g.AppliesTo(opt.GOOS) {
			continue
		}

		out := Group{ID: g.ID, Label: g.Label, Detail: g.Detail, Selected: true}

		for _, e := range g.Entries {
			out.Actions = append(out.Actions, Action{
				Source: filepath.Join(opt.Repo, e.Source),
				Dest:   filepath.Join(opt.Home, e.Dest),
				Label:  "~/" + e.Dest,
			})
		}

		if g.FanoutSource != "" {
			actions, err := expandFanout(g, opt)
			if err != nil {
				return nil, err
			}
			out.Actions = append(out.Actions, actions...)
		}

		p.Groups = append(p.Groups, out)
	}

	return p, nil
}

// expandFanout installs every child of one directory into several destinations.
//
// A missing source is an error rather than an empty expansion: a typo would
// otherwise mean the skills are silently never installed, and nothing about the
// run would look wrong.
func expandFanout(g manifest.Group, opt Options) ([]Action, error) {
	root := filepath.Join(opt.Repo, g.FanoutSource)
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, fmt.Errorf("plan: fan-out source for group %q: %w", g.ID, err)
	}

	var actions []Action
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		for _, dest := range g.FanoutDests {
			rel := filepath.Join(dest, e.Name())
			actions = append(actions, Action{
				Source: filepath.Join(root, e.Name()),
				Dest:   filepath.Join(opt.Home, rel),
				Label:  "~/" + rel,
			})
		}
	}
	return actions, nil
}

// SelectedActions flattens the plan down to what the user actually ticked.
func (p *Plan) SelectedActions() []Action {
	var out []Action
	for _, g := range p.Groups {
		if !g.Selected {
			continue
		}
		out = append(out, g.Actions...)
	}
	return out
}

// Total is every action in the plan, selected or not.
func (p *Plan) Total() int {
	n := 0
	for _, g := range p.Groups {
		n += len(g.Actions)
	}
	return n
}
