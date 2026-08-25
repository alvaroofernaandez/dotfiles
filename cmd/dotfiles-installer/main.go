// Command dotfiles-installer installs this repository's configs on macOS,
// Linux and Windows.
//
//	dotfiles-installer            interactive TUI
//	dotfiles-installer --dry-run  show what would happen, change nothing
//	dotfiles-installer update     pull the repo, then re-apply
//	dotfiles-installer --version  print the version
//
// The non-interactive paths matter as much as the TUI: --yes makes it usable
// from a provisioning script, and update is what a cron job or a shell hook
// calls to keep a machine current.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/alvaroofernaandez/dotfiles/internal/install"
	"github.com/alvaroofernaandez/dotfiles/internal/manifest"
	"github.com/alvaroofernaandez/dotfiles/internal/plan"
	"github.com/alvaroofernaandez/dotfiles/internal/platform"
	"github.com/alvaroofernaandez/dotfiles/internal/ui"
	"github.com/alvaroofernaandez/dotfiles/internal/update"
)

// version is stamped at build time:
//
//	go build -ldflags "-X main.version=$(git describe --tags --always)"
var version = "dev"

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	var (
		dryRun    = flag.Bool("dry-run", false, "show what would happen, change nothing")
		yes       = flag.Bool("yes", false, "install everything applicable without the TUI")
		repoFlag  = flag.String("repo", "", "path to the dotfiles repository (default: the binary's repository)")
		showVer   = flag.Bool("version", false, "print the version and exit")
		forceCopy = flag.Bool("copy", false, "copy files instead of symlinking them")
	)
	flag.Parse()

	if *showVer {
		fmt.Printf("dotfiles-installer %s (%s/%s)\n", version, runtime.GOOS, runtime.GOARCH)
		return nil
	}

	repo, err := resolveRepo(*repoFlag)
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	if flag.Arg(0) == "update" {
		return runUpdate(repo, home, *dryRun, *forceCopy)
	}

	return runInstall(repo, home, *dryRun, *yes, *forceCopy)
}

// resolveRepo finds the repository. The binary normally lives inside it, so
// walking up from the executable finds it without configuration — but a
// go-installed binary sits in GOPATH/bin, so the working directory and the
// flag are both honoured.
func resolveRepo(flagValue string) (string, error) {
	candidates := []string{}
	if flagValue != "" {
		candidates = append(candidates, flagValue)
	}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Dir(exe), filepath.Join(filepath.Dir(exe), ".."))
	}
	if wd, err := os.Getwd(); err == nil {
		candidates = append(candidates, wd)
	}

	for _, c := range candidates {
		if root := walkUpToManifest(c); root != "" {
			return root, nil
		}
	}
	return "", fmt.Errorf("cannot find install.manifest; run from the repository or pass --repo")
}

func walkUpToManifest(start string) string {
	dir, err := filepath.Abs(start)
	if err != nil {
		return ""
	}
	for i := 0; i < 6; i++ {
		if _, err := os.Stat(filepath.Join(dir, "install.manifest")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ""
}

// buildPlan is shared by install and update so the two can never disagree
// about what belongs on this machine.
func buildPlan(repo, home string) (*manifest.Manifest, *plan.Plan, platform.Platform, error) {
	pf := platform.Detect()

	m, err := manifest.Load(filepath.Join(repo, "install.manifest"))
	if err != nil {
		return nil, nil, pf, err
	}
	p, err := plan.Build(m, plan.Options{Repo: repo, Home: home, GOOS: runtime.GOOS})
	if err != nil {
		return nil, nil, pf, err
	}
	return m, p, pf, nil
}

// symlinkMode decides link-vs-copy by probing rather than by consulting GOOS:
// on Windows the answer depends on Developer Mode and elevation, neither of
// which is knowable in advance.
func symlinkMode(pf platform.Platform, home string, forceCopy bool) bool {
	if forceCopy {
		return false
	}
	return pf.SupportsSymlinks(home)
}

// unavailableGroups lists what this machine cannot take, so the TUI can show
// it greyed out instead of silently omitting it.
func unavailableGroups(m *manifest.Manifest) []ui.UnavailableGroup {
	var out []ui.UnavailableGroup
	for _, g := range m.Groups {
		if !g.AppliesTo(runtime.GOOS) {
			out = append(out, ui.UnavailableGroup{
				Label:  g.Label,
				Reason: "not available on Windows natively — use WSL",
			})
		}
	}
	return out
}

func runInstall(repo, home string, dryRun, yes, forceCopy bool) error {
	m, p, pf, err := buildPlan(repo, home)
	if err != nil {
		return err
	}
	if len(p.Groups) == 0 {
		return fmt.Errorf("nothing in the manifest applies to %s", pf.Display())
	}

	symlinks := symlinkMode(pf, home, forceCopy)
	runner := install.New(install.Options{Home: home, Symlinks: symlinks, DryRun: dryRun})

	if yes {
		return runHeadless(p, pf, runner, symlinks, dryRun)
	}

	model := ui.NewModel(p, pf, runner, symlinks, dryRun)
	model.Unavailable = unavailableGroups(m)

	final, err := tea.NewProgram(model, tea.WithAltScreen()).Run()
	if err != nil {
		return err
	}
	if fm, ok := final.(ui.Model); ok && len(fm.Errs()) > 0 {
		return fmt.Errorf("%d action(s) failed", len(fm.Errs()))
	}
	return nil
}

// runHeadless is the provisioning path: no TUI, one line per action, and a
// non-zero exit if anything failed.
func runHeadless(p *plan.Plan, pf platform.Platform, runner *install.Runner, symlinks, dryRun bool) error {
	fmt.Printf("dotfiles-installer %s — %s\n", version, pf.Display())
	fmt.Printf("%s\n\n", pf.InstallStyle(symlinks))

	var failures int
	backups := 0
	for _, a := range p.SelectedActions() {
		res, err := runner.Apply(a)
		if err != nil {
			fmt.Printf("  %-44s %s\n", a.Label, "FAILED: "+err.Error())
			failures++
			continue
		}
		note := ""
		if res.Backup != "" {
			note = "  (backed up)"
			backups++
		}
		fmt.Printf("  %-44s %s%s\n", a.Label, res.Status, note)
	}

	if backups > 0 {
		fmt.Printf("\n%d existing file(s) moved to %s\n", backups, runner.BackupRoot())
	}
	if failures > 0 {
		return fmt.Errorf("%d action(s) failed", failures)
	}
	if dryRun {
		fmt.Println("\nDry run — nothing was written.")
	}
	return nil
}

// runUpdate pulls the repository and re-applies.
//
// Pulling is most of the update on its own, because the configs are symlinks:
// they change the instant the working tree does. What pulling misses is new
// manifest entries and newly added skills, which have no link yet — hence the
// re-apply, which is a no-op for everything already in place.
func runUpdate(repo, home string, dryRun, forceCopy bool) error {
	ctx, cancel := context.WithTimeout(context.Background(), update.DefaultTimeout)
	defer cancel()

	git := update.NewGit(repo)
	status, err := update.Pull(ctx, git)
	if err != nil {
		return err
	}

	switch {
	case status.Updated:
		fmt.Printf("Updated %s → %s (%d commit(s))\n", status.Current, status.Latest, status.Behind)
	default:
		fmt.Printf("Already up to date (%s)\n", status.Current)
	}

	// Re-apply regardless of whether anything was pulled: a previous run may
	// have been interrupted, or a skill added by hand may still be unlinked.
	_, p, pf, err := buildPlan(repo, home)
	if err != nil {
		return err
	}
	symlinks := symlinkMode(pf, home, forceCopy)
	runner := install.New(install.Options{Home: home, Symlinks: symlinks, DryRun: dryRun})

	var changed, failed int
	for _, a := range p.SelectedActions() {
		res, err := runner.Apply(a)
		if err != nil {
			fmt.Fprintf(os.Stderr, "  %-44s FAILED: %v\n", a.Label, err)
			failed++
			continue
		}
		if res.Status != install.StatusAlready {
			fmt.Printf("  %-44s %s\n", a.Label, res.Status)
			changed++
		}
	}

	if changed == 0 && failed == 0 {
		fmt.Println("Everything already linked.")
	}
	if failed > 0 {
		return fmt.Errorf("%d action(s) failed", failed)
	}
	return nil
}
