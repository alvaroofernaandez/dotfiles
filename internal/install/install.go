// Package install executes a plan against the filesystem.
//
// It keeps the promise install.sh makes and that users rely on: nothing is ever
// deleted. Anything already sitting at a destination is moved into a timestamped
// quarantine directory before the new entry takes its place, and re-running is a
// no-op for entries already pointing at the repo.
package install

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/alvaroofernaandez/dotfiles/internal/plan"
)

// Status is what happened to one action.
type Status int

const (
	StatusLinked  Status = iota // a symlink was created
	StatusCopied                // content was copied (Windows without symlink rights)
	StatusAlready               // already pointing at the repo; nothing done
	StatusWould                 // dry run
)

func (s Status) String() string {
	switch s {
	case StatusLinked:
		return "linked"
	case StatusCopied:
		return "copied"
	case StatusAlready:
		return "already installed"
	case StatusWould:
		return "would install"
	}
	return "unknown"
}

// Result describes one completed action.
type Result struct {
	Action plan.Action
	Status Status
	// Backup is where a displaced file went, empty if nothing was displaced.
	Backup string
}

// Options configures a Runner.
type Options struct {
	Home string
	// Symlinks selects link-vs-copy. It comes from a real probe on Windows
	// rather than from GOOS, since the answer depends on Developer Mode.
	Symlinks bool
	DryRun   bool
	// BackupRoot overrides where displaced files go. Empty means
	// ~/.dotfiles-backup/<timestamp>.
	BackupRoot string
}

// Runner applies actions.
type Runner struct {
	opt Options
}

// New builds a Runner, fixing the backup directory for the whole run so that
// everything displaced by one invocation lands together.
func New(opt Options) *Runner {
	if opt.BackupRoot == "" {
		stamp := time.Now().Format("20060102150405")
		opt.BackupRoot = filepath.Join(opt.Home, ".dotfiles-backup", stamp)
	}
	return &Runner{opt: opt}
}

// BackupRoot is where this run puts displaced files.
func (r *Runner) BackupRoot() string { return r.opt.BackupRoot }

// Apply performs one action.
func (r *Runner) Apply(a plan.Action) (Result, error) {
	res := Result{Action: a}

	if _, err := os.Stat(a.Source); err != nil {
		return res, fmt.Errorf("install: source missing: %s", a.Source)
	}

	// Already correct? Nothing to do — this is what makes re-running safe.
	if r.opt.Symlinks {
		if target, err := os.Readlink(a.Dest); err == nil && target == a.Source {
			res.Status = StatusAlready
			return res, nil
		}
	}

	if r.opt.DryRun {
		res.Status = StatusWould
		return res, nil
	}

	if err := os.MkdirAll(filepath.Dir(a.Dest), 0o755); err != nil {
		return res, fmt.Errorf("install: %w", err)
	}

	// Lstat, not Stat: Stat follows links and reports false for a broken one,
	// which would leave the broken link in place and fail the create below.
	if _, err := os.Lstat(a.Dest); err == nil {
		backup, err := r.backup(a)
		if err != nil {
			return res, err
		}
		res.Backup = backup
	}

	if r.opt.Symlinks {
		if err := os.Symlink(a.Source, a.Dest); err != nil {
			return res, fmt.Errorf("install: link %s: %w", a.Label, err)
		}
		res.Status = StatusLinked
		return res, nil
	}

	if err := copyPath(a.Source, a.Dest); err != nil {
		return res, fmt.Errorf("install: copy %s: %w", a.Label, err)
	}
	res.Status = StatusCopied
	return res, nil
}

// backup moves whatever is at the destination into the quarantine directory.
//
// The quarantine sits outside the config tree on purpose. Tools scan their
// config directories wholesale — Claude Code loads every entry under
// ~/.claude/skills — so a "ship.bak" left beside "ship" would be picked up as a
// second, duplicate skill.
func (r *Runner) backup(a plan.Action) (string, error) {
	rel, err := filepath.Rel(r.opt.Home, a.Dest)
	if err != nil {
		rel = filepath.Base(a.Dest)
	}
	dest := filepath.Join(r.opt.BackupRoot, rel)

	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return "", fmt.Errorf("install: backup dir: %w", err)
	}
	if err := os.Rename(a.Dest, dest); err != nil {
		// Rename fails across filesystems, which happens when $HOME and the
		// backup root sit on different mounts. Fall back to copy-then-remove so
		// the original still survives.
		if err := copyPath(a.Dest, dest); err != nil {
			return "", fmt.Errorf("install: backup %s: %w", a.Label, err)
		}
		if err := os.RemoveAll(a.Dest); err != nil {
			return "", fmt.Errorf("install: clear %s: %w", a.Label, err)
		}
	}
	return dest, nil
}

// copyPath copies a file or a directory tree, preserving permission bits.
// Most manifest entries are directories, and the tmux scripts among them are
// only useful if the executable bit survives.
func copyPath(src, dst string) error {
	fi, err := os.Lstat(src)
	if err != nil {
		return err
	}

	if fi.Mode()&os.ModeSymlink != 0 {
		target, err := os.Readlink(src)
		if err != nil {
			return err
		}
		_ = os.Remove(dst)
		return os.Symlink(target, dst)
	}

	if !fi.IsDir() {
		return copyFile(src, dst, fi.Mode().Perm())
	}

	if err := os.MkdirAll(dst, fi.Mode().Perm()); err != nil {
		return err
	}
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if err := copyPath(filepath.Join(src, e.Name()), filepath.Join(dst, e.Name())); err != nil {
			return err
		}
	}
	return nil
}

func copyFile(src, dst string, perm os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, perm)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}
