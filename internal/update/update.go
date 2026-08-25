// Package update refreshes an existing installation.
//
// Because configs are symlinked into $HOME, pulling the repository is most of
// the update: every linked file changes the moment the working tree does. What
// pulling does NOT cover is new manifest entries and newly added skills, which
// have no link yet — so an update is "pull, then re-apply the plan", and the
// re-apply is a no-op for everything already pointing at the repo.
//
// On Windows without symlink rights the files were copied, so the re-apply is
// the entire update rather than a formality.
package update

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// Git runs git commands in a repository. It is an interface so the update
// logic is testable without a network or a real clone.
type Git interface {
	Run(ctx context.Context, args ...string) (string, error)
}

// execGit is the real implementation.
type execGit struct{ dir string }

// NewGit returns a Git bound to a repository directory.
func NewGit(dir string) Git { return &execGit{dir: dir} }

func (g *execGit) Run(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = g.dir
	out, err := cmd.CombinedOutput()
	text := strings.TrimSpace(string(out))
	if err != nil {
		return text, fmt.Errorf("git %s: %w: %s", strings.Join(args, " "), err, text)
	}
	return text, nil
}

// Status describes what an update found.
type Status struct {
	Current   string // short SHA before the pull
	Latest    string // short SHA after
	Behind    int    // commits pulled
	Updated   bool
	DirtyTree bool // local modifications; the pull is skipped
}

// Check reports whether the repository is behind its remote, without changing
// anything.
func Check(ctx context.Context, g Git) (Status, error) {
	var s Status

	head, err := g.Run(ctx, "rev-parse", "--short", "HEAD")
	if err != nil {
		return s, err
	}
	s.Current = head

	// A dirty tree is reported rather than stashed. Silently moving someone's
	// uncommitted work is exactly the kind of thing an installer must not do.
	dirty, err := g.Run(ctx, "status", "--porcelain")
	if err != nil {
		return s, err
	}
	s.DirtyTree = dirty != ""

	if _, err := g.Run(ctx, "fetch", "--quiet", "origin"); err != nil {
		return s, err
	}

	count, err := g.Run(ctx, "rev-list", "--count", "HEAD..@{upstream}")
	if err != nil {
		// No upstream configured is a normal state for a local clone, not a
		// failure worth aborting on.
		s.Latest = s.Current
		return s, nil
	}
	fmt.Sscanf(count, "%d", &s.Behind)

	latest, err := g.Run(ctx, "rev-parse", "--short", "@{upstream}")
	if err != nil {
		s.Latest = s.Current
		return s, nil
	}
	s.Latest = latest
	return s, nil
}

// Pull fast-forwards the repository. It refuses to touch a dirty tree.
func Pull(ctx context.Context, g Git) (Status, error) {
	s, err := Check(ctx, g)
	if err != nil {
		return s, err
	}
	if s.DirtyTree {
		return s, fmt.Errorf("update: the repository has uncommitted changes; commit or stash them first")
	}
	if s.Behind == 0 {
		return s, nil
	}

	// --ff-only, never a merge: an installer that creates merge commits in
	// someone's dotfiles repo has overstepped.
	if _, err := g.Run(ctx, "pull", "--ff-only", "--quiet"); err != nil {
		return s, err
	}
	s.Updated = true
	return s, nil
}

// DefaultTimeout bounds network operations so a hung fetch cannot wedge the
// installer indefinitely.
const DefaultTimeout = 60 * time.Second
