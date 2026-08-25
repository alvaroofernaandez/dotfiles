package plan

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/alvaroofernaandez/dotfiles/internal/manifest"
)

func testManifest(t *testing.T, repo string) *manifest.Manifest {
	t.Helper()
	// A fan-out source with two children, so the expansion is observable.
	for _, s := range []string{"alpha", "beta"} {
		if err := os.MkdirAll(filepath.Join(repo, "shared/skills", s), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return &manifest.Manifest{Groups: []manifest.Group{
		{
			ID: "terminal", Label: "Terminal", Platforms: manifest.PlatformUnix,
			Entries: []manifest.Entry{{Source: "config/tmux", Dest: ".config/tmux"}},
		},
		{
			ID: "claude", Label: "Claude", Platforms: manifest.PlatformAll,
			Entries: []manifest.Entry{{Source: "config/claude/CLAUDE.md", Dest: ".claude/CLAUDE.md"}},
		},
		{
			ID: "skills", Label: "Skills", Platforms: manifest.PlatformAll,
			FanoutSource: "shared/skills",
			FanoutDests:  []string{".claude/skills", ".opencode/skills"},
		},
	}}
}

func TestBuildDropsGroupsThatDoNotApply(t *testing.T) {
	repo := t.TempDir()
	m := testManifest(t, repo)

	p, err := Build(m, Options{Repo: repo, Home: "/home/u", GOOS: "windows"})
	if err != nil {
		t.Fatal(err)
	}
	for _, g := range p.Groups {
		if g.ID == "terminal" {
			t.Error("the unix-only terminal group must not be offered on Windows")
		}
	}
	if len(p.Groups) != 2 {
		t.Errorf("groups on Windows = %d, want 2", len(p.Groups))
	}
}

func TestBuildKeepsEveryGroupOnUnix(t *testing.T) {
	repo := t.TempDir()
	p, err := Build(testManifest(t, repo), Options{Repo: repo, Home: "/home/u", GOOS: "darwin"})
	if err != nil {
		t.Fatal(err)
	}
	if len(p.Groups) != 3 {
		t.Errorf("groups on macOS = %d, want 3", len(p.Groups))
	}
}

func TestBuildExpandsTheFanout(t *testing.T) {
	repo := t.TempDir()
	p, err := Build(testManifest(t, repo), Options{Repo: repo, Home: "/home/u", GOOS: "darwin"})
	if err != nil {
		t.Fatal(err)
	}
	var skills *Group
	for i := range p.Groups {
		if p.Groups[i].ID == "skills" {
			skills = &p.Groups[i]
		}
	}
	if skills == nil {
		t.Fatal("skills group missing")
	}
	// 2 skills x 2 destinations.
	if got, want := len(skills.Actions), 4; got != want {
		t.Fatalf("fan-out actions = %d, want %d", got, want)
	}
	seen := map[string]bool{}
	for _, a := range skills.Actions {
		seen[a.Dest] = true
	}
	for _, want := range []string{
		"/home/u/.claude/skills/alpha",
		"/home/u/.opencode/skills/beta",
	} {
		if !seen[want] {
			t.Errorf("missing expanded destination %q", want)
		}
	}
}

func TestBuildMakesPathsAbsolute(t *testing.T) {
	// The executor never re-resolves paths, so anything relative that survives
	// here would be created relative to the process working directory.
	repo := t.TempDir()
	p, err := Build(testManifest(t, repo), Options{Repo: repo, Home: "/home/u", GOOS: "darwin"})
	if err != nil {
		t.Fatal(err)
	}
	for _, g := range p.Groups {
		for _, a := range g.Actions {
			if !filepath.IsAbs(a.Source) || !filepath.IsAbs(a.Dest) {
				t.Errorf("action has a relative path: %+v", a)
			}
		}
	}
}

func TestBuildSelectsApplicableGroupsByDefault(t *testing.T) {
	// The TUI starts with everything that applies already ticked: the common
	// case is "install all of it", and an all-empty list makes the user work
	// before they can do anything.
	repo := t.TempDir()
	p, err := Build(testManifest(t, repo), Options{Repo: repo, Home: "/home/u", GOOS: "darwin"})
	if err != nil {
		t.Fatal(err)
	}
	for _, g := range p.Groups {
		if !g.Selected {
			t.Errorf("group %q should start selected", g.ID)
		}
	}
}

func TestSelectedActionsHonoursSelection(t *testing.T) {
	repo := t.TempDir()
	p, err := Build(testManifest(t, repo), Options{Repo: repo, Home: "/home/u", GOOS: "darwin"})
	if err != nil {
		t.Fatal(err)
	}
	for i := range p.Groups {
		p.Groups[i].Selected = p.Groups[i].ID == "claude"
	}
	actions := p.SelectedActions()
	if got, want := len(actions), 1; got != want {
		t.Fatalf("selected actions = %d, want %d", got, want)
	}
	if actions[0].Dest != "/home/u/.claude/CLAUDE.md" {
		t.Errorf("unexpected action: %+v", actions[0])
	}
}

func TestBuildReportsAMissingFanoutSource(t *testing.T) {
	// A typo'd fan-out path would otherwise expand to nothing and the skills
	// would silently never be installed.
	m := &manifest.Manifest{Groups: []manifest.Group{{
		ID: "skills", Label: "Skills", Platforms: manifest.PlatformAll,
		FanoutSource: "does/not/exist",
		FanoutDests:  []string{".claude/skills"},
	}}}
	_, err := Build(m, Options{Repo: t.TempDir(), Home: "/home/u", GOOS: "darwin"})
	if err == nil {
		t.Fatal("expected an error for a missing fan-out source")
	}
}

func TestCountsAreReportedForTheUI(t *testing.T) {
	repo := t.TempDir()
	p, err := Build(testManifest(t, repo), Options{Repo: repo, Home: "/home/u", GOOS: "darwin"})
	if err != nil {
		t.Fatal(err)
	}
	if got := p.Total(); got != 6 { // 1 + 1 + 4
		t.Errorf("Total() = %d, want 6", got)
	}
}
