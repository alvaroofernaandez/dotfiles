package install

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/alvaroofernaandez/dotfiles/internal/plan"
)

func fixture(t *testing.T) (repo, home string, act plan.Action) {
	t.Helper()
	repo, home = t.TempDir(), t.TempDir()
	src := filepath.Join(repo, "zshrc")
	if err := os.WriteFile(src, []byte("# from repo\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return repo, home, plan.Action{Source: src, Dest: filepath.Join(home, ".zshrc"), Label: "~/.zshrc"}
}

func TestLinkCreatesASymlink(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("symlink creation needs Developer Mode on Windows")
	}
	_, home, act := fixture(t)
	r := New(Options{Home: home, Symlinks: true})

	res, err := r.Apply(act)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if res.Status != StatusLinked {
		t.Errorf("status = %v, want linked", res.Status)
	}
	target, err := os.Readlink(act.Dest)
	if err != nil {
		t.Fatalf("Readlink: %v", err)
	}
	if target != act.Source {
		t.Errorf("link points at %q, want %q", target, act.Source)
	}
}

func TestCopyWritesRealContent(t *testing.T) {
	// The Windows path. The installed file must be a real file, not a link.
	_, home, act := fixture(t)
	r := New(Options{Home: home, Symlinks: false})

	res, err := r.Apply(act)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if res.Status != StatusCopied {
		t.Errorf("status = %v, want copied", res.Status)
	}
	b, err := os.ReadFile(act.Dest)
	if err != nil {
		t.Fatal(err)
	}
	if string(b) != "# from repo\n" {
		t.Errorf("content = %q", b)
	}
	if fi, err := os.Lstat(act.Dest); err == nil && fi.Mode()&os.ModeSymlink != 0 {
		t.Error("copy mode must not produce a symlink")
	}
}

func TestCopyHandlesDirectories(t *testing.T) {
	// Most manifest entries are directories (config/tmux, .claude/agents), so a
	// copier that only handled files would fail on nearly everything.
	repo, home := t.TempDir(), t.TempDir()
	srcDir := filepath.Join(repo, "tmux")
	if err := os.MkdirAll(filepath.Join(srcDir, "tests"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(srcDir, "a.sh"), []byte("a"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(srcDir, "tests", "b.sh"), []byte("b"), 0o644); err != nil {
		t.Fatal(err)
	}

	r := New(Options{Home: home, Symlinks: false})
	act := plan.Action{Source: srcDir, Dest: filepath.Join(home, ".config", "tmux"), Label: "~/.config/tmux"}
	if _, err := r.Apply(act); err != nil {
		t.Fatalf("Apply: %v", err)
	}

	b, err := os.ReadFile(filepath.Join(home, ".config", "tmux", "tests", "b.sh"))
	if err != nil {
		t.Fatalf("nested file not copied: %v", err)
	}
	if string(b) != "b" {
		t.Errorf("nested content = %q", b)
	}
	fi, err := os.Stat(filepath.Join(home, ".config", "tmux", "a.sh"))
	if err != nil {
		t.Fatal(err)
	}
	if runtime.GOOS != "windows" && fi.Mode().Perm()&0o111 == 0 {
		t.Error("the executable bit must survive the copy: these are scripts")
	}
}

func TestExistingFileIsBackedUpNeverDeleted(t *testing.T) {
	// The promise install.sh makes, and the one that matters most: whatever the
	// user already had is still on disk afterwards.
	_, home, act := fixture(t)
	if err := os.WriteFile(act.Dest, []byte("PRECIOUS"), 0o644); err != nil {
		t.Fatal(err)
	}

	r := New(Options{Home: home, Symlinks: true})
	res, err := r.Apply(act)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if res.Backup == "" {
		t.Fatal("a displaced file must report where it went")
	}
	b, err := os.ReadFile(res.Backup)
	if err != nil {
		t.Fatalf("backup unreadable: %v", err)
	}
	if string(b) != "PRECIOUS" {
		t.Errorf("backup content = %q, want PRECIOUS", b)
	}
}

func TestBackupsGoOutsideTheConfigDirectory(t *testing.T) {
	// Tools scan config directories wholesale — Claude Code loads every entry
	// under ~/.claude/skills — so a "ship.bak" left beside "ship" is picked up
	// as a second, duplicate skill. Backups are quarantined instead.
	// A nested destination, because that is where the rule bites: a displaced
	// skill left beside its replacement is loaded as a second, duplicate skill.
	// (A file directly in $HOME cannot demonstrate this — the quarantine
	// directory is itself under $HOME.)
	repo, home := t.TempDir(), t.TempDir()
	src := filepath.Join(repo, "ship")
	if err := os.MkdirAll(src, 0o755); err != nil {
		t.Fatal(err)
	}
	act := plan.Action{
		Source: src,
		Dest:   filepath.Join(home, ".claude", "skills", "ship"),
		Label:  "~/.claude/skills/ship",
	}
	if err := os.MkdirAll(act.Dest, 0o755); err != nil {
		t.Fatal(err)
	}

	r := New(Options{Home: home, Symlinks: true})
	res, err := r.Apply(act)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}

	skillsDir := filepath.Dir(act.Dest)
	if strings.HasPrefix(res.Backup, skillsDir+string(filepath.Separator)) {
		t.Errorf("backup %q sits inside the skills directory it was displaced from", res.Backup)
	}
	if !strings.Contains(res.Backup, ".dotfiles-backup") {
		t.Errorf("backup %q is not in the quarantine directory", res.Backup)
	}

	// And the skills directory holds exactly the new link, nothing extra.
	entries, err := os.ReadDir(skillsDir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 {
		t.Errorf("skills directory holds %d entries, want 1", len(entries))
	}
}

func TestAlreadyLinkedIsANoop(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("symlink creation needs Developer Mode on Windows")
	}
	_, home, act := fixture(t)
	r := New(Options{Home: home, Symlinks: true})
	if _, err := r.Apply(act); err != nil {
		t.Fatal(err)
	}

	res, err := r.Apply(act)
	if err != nil {
		t.Fatalf("second Apply: %v", err)
	}
	if res.Status != StatusAlready {
		t.Errorf("status = %v, want already", res.Status)
	}
	if res.Backup != "" {
		t.Errorf("re-running must not back anything up, got %q", res.Backup)
	}
}

func TestBrokenSymlinkIsReplaced(t *testing.T) {
	// os.Stat is false for a broken link, so a naive existence check leaves it
	// in place and the new link is never created.
	if runtime.GOOS == "windows" {
		t.Skip("symlink creation needs Developer Mode on Windows")
	}
	_, home, act := fixture(t)
	if err := os.Symlink(filepath.Join(home, "nowhere"), act.Dest); err != nil {
		t.Fatal(err)
	}

	r := New(Options{Home: home, Symlinks: true})
	if _, err := r.Apply(act); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	target, err := os.Readlink(act.Dest)
	if err != nil {
		t.Fatal(err)
	}
	if target != act.Source {
		t.Errorf("broken link was not replaced: points at %q", target)
	}
}

func TestDryRunTouchesNothing(t *testing.T) {
	_, home, act := fixture(t)
	r := New(Options{Home: home, Symlinks: true, DryRun: true})

	res, err := r.Apply(act)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if res.Status != StatusWould {
		t.Errorf("status = %v, want would", res.Status)
	}
	if _, err := os.Lstat(act.Dest); !os.IsNotExist(err) {
		t.Error("dry run created the destination")
	}
}

func TestMissingSourceIsReported(t *testing.T) {
	_, home, _ := fixture(t)
	r := New(Options{Home: home, Symlinks: true})
	_, err := r.Apply(plan.Action{Source: filepath.Join(home, "nope"), Dest: filepath.Join(home, ".x")})
	if err == nil {
		t.Fatal("expected an error for a missing source")
	}
}

func TestParentDirectoriesAreCreated(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("symlink creation needs Developer Mode on Windows")
	}
	repo, home := t.TempDir(), t.TempDir()
	src := filepath.Join(repo, "config.json")
	if err := os.WriteFile(src, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	r := New(Options{Home: home, Symlinks: true})
	act := plan.Action{Source: src, Dest: filepath.Join(home, ".config", "deep", "nested", "config.json")}
	if _, err := r.Apply(act); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if _, err := os.Lstat(act.Dest); err != nil {
		t.Errorf("destination not created: %v", err)
	}
}
