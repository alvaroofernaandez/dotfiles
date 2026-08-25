package manifest

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const sample = `
# a comment
[terminal]
label = Terminal environment
detail = tmux and friends
platforms = unix

config/tmux        .config/tmux
home/zshrc         .zshrc

[claude]
label = Claude Code
detail = Agent config
platforms = all

config/claude/CLAUDE.md   .claude/CLAUDE.md

[skills]
label = Agent skills
detail = Shared skills
platforms = all

fanout-source = shared/skills
fanout-dests = .claude/skills .opencode/skills
`

func parseSample(t *testing.T) *Manifest {
	t.Helper()
	m, err := Parse(strings.NewReader(sample))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	return m
}

func TestParseReadsEveryGroup(t *testing.T) {
	m := parseSample(t)
	if got, want := len(m.Groups), 3; got != want {
		t.Fatalf("groups = %d, want %d", got, want)
	}
	for i, want := range []string{"terminal", "claude", "skills"} {
		if got := m.Groups[i].ID; got != want {
			t.Errorf("group %d id = %q, want %q", i, got, want)
		}
	}
}

func TestParseKeepsGroupOrder(t *testing.T) {
	// The TUI renders groups in file order. Sorting them by map iteration would
	// shuffle the list between runs and make the golden UI tests flap.
	m := parseSample(t)
	if m.Groups[0].ID != "terminal" {
		t.Errorf("first group = %q, want terminal", m.Groups[0].ID)
	}
}

func TestParseReadsMetadata(t *testing.T) {
	m := parseSample(t)
	g := m.Groups[0]
	if g.Label != "Terminal environment" {
		t.Errorf("label = %q", g.Label)
	}
	if g.Detail != "tmux and friends" {
		t.Errorf("detail = %q", g.Detail)
	}
	if g.Platforms != PlatformUnix {
		t.Errorf("platforms = %v, want unix", g.Platforms)
	}
}

func TestParseReadsEntries(t *testing.T) {
	m := parseSample(t)
	g := m.Groups[0]
	if got, want := len(g.Entries), 2; got != want {
		t.Fatalf("entries = %d, want %d", got, want)
	}
	if g.Entries[0].Source != "config/tmux" || g.Entries[0].Dest != ".config/tmux" {
		t.Errorf("entry 0 = %+v", g.Entries[0])
	}
}

func TestParseReadsFanout(t *testing.T) {
	m := parseSample(t)
	g := m.Groups[2]
	if g.FanoutSource != "shared/skills" {
		t.Errorf("fanout source = %q", g.FanoutSource)
	}
	if got, want := len(g.FanoutDests), 2; got != want {
		t.Fatalf("fanout dests = %d, want %d", got, want)
	}
	if g.FanoutDests[1] != ".opencode/skills" {
		t.Errorf("fanout dest 1 = %q", g.FanoutDests[1])
	}
}

func TestParseIgnoresCommentsAndBlanks(t *testing.T) {
	// A trailing comment on an entry line would otherwise be read as the
	// destination, producing a link into a path named "#".
	m, err := Parse(strings.NewReader("[g]\nlabel = L\nplatforms = all\n\n  # only a comment\nsrc  dst   # trailing\n"))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if got, want := len(m.Groups[0].Entries), 1; got != want {
		t.Fatalf("entries = %d, want %d", got, want)
	}
	if m.Groups[0].Entries[0].Dest != "dst" {
		t.Errorf("dest = %q, want dst", m.Groups[0].Entries[0].Dest)
	}
}

func TestParseRejectsUnknownPlatform(t *testing.T) {
	// Silently defaulting would install a Unix-only group on Windows.
	_, err := Parse(strings.NewReader("[g]\nlabel = L\nplatforms = solaris\n"))
	if err == nil {
		t.Fatal("expected an error for an unknown platform")
	}
	if !strings.Contains(err.Error(), "solaris") {
		t.Errorf("error should name the bad value, got: %v", err)
	}
}

func TestParseRejectsGroupWithoutPlatform(t *testing.T) {
	_, err := Parse(strings.NewReader("[g]\nlabel = L\nsrc dst\n"))
	if err == nil {
		t.Fatal("expected an error for a group with no platforms key")
	}
}

func TestParseRejectsEntryOutsideGroup(t *testing.T) {
	// An entry before any header belongs to nothing and would be dropped.
	_, err := Parse(strings.NewReader("src  dst\n[g]\nlabel = L\nplatforms = all\n"))
	if err == nil {
		t.Fatal("expected an error for an entry outside a group")
	}
}

func TestGroupAppliesTo(t *testing.T) {
	unix := Group{Platforms: PlatformUnix}
	all := Group{Platforms: PlatformAll}

	cases := []struct {
		os       string
		unixWant bool
		allWant  bool
	}{
		{"darwin", true, true},
		{"linux", true, true},
		{"windows", false, true},
	}
	for _, c := range cases {
		if got := unix.AppliesTo(c.os); got != c.unixWant {
			t.Errorf("unix group on %s = %v, want %v", c.os, got, c.unixWant)
		}
		if got := all.AppliesTo(c.os); got != c.allWant {
			t.Errorf("all group on %s = %v, want %v", c.os, got, c.allWant)
		}
	}
}

func TestLoadReadsTheRealManifest(t *testing.T) {
	// The repo's own manifest must parse. This is what stops a hand edit that
	// breaks the format from reaching a user's machine.
	path := filepath.Join("..", "..", "install.manifest")
	if _, err := os.Stat(path); err != nil {
		t.Skipf("manifest not found: %v", err)
	}
	m, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(m.Groups) < 3 {
		t.Errorf("real manifest has %d groups, expected at least 3", len(m.Groups))
	}
	for _, g := range m.Groups {
		if g.Label == "" {
			t.Errorf("group %q has no label", g.ID)
		}
	}
}
