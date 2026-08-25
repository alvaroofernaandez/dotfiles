package ui

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/alvaroofernaandez/dotfiles/internal/install"
	"github.com/alvaroofernaandez/dotfiles/internal/plan"
	"github.com/alvaroofernaandez/dotfiles/internal/platform"
)

func testModel(t *testing.T) Model {
	t.Helper()
	repo, home := t.TempDir(), t.TempDir()
	for _, n := range []string{"a", "b"} {
		if err := os.WriteFile(filepath.Join(repo, n), []byte(n), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	p := &plan.Plan{Groups: []plan.Group{
		{ID: "one", Label: "Group One", Detail: "first", Selected: true, Actions: []plan.Action{
			{Source: filepath.Join(repo, "a"), Dest: filepath.Join(home, ".a"), Label: "~/.a"},
		}},
		{ID: "two", Label: "Group Two", Detail: "second", Selected: true, Actions: []plan.Action{
			{Source: filepath.Join(repo, "b"), Dest: filepath.Join(home, ".b"), Label: "~/.b"},
		}},
	}}
	r := install.New(install.Options{Home: home, Symlinks: true})
	return NewModel(p, platform.Platform{OS: "darwin", Arch: "arm64"}, r, true, false)
}

func key(s string) tea.KeyMsg {
	if s == " " {
		return tea.KeyMsg{Type: tea.KeySpace}
	}
	if len(s) > 1 {
		switch s {
		case "up":
			return tea.KeyMsg{Type: tea.KeyUp}
		case "down":
			return tea.KeyMsg{Type: tea.KeyDown}
		case "enter":
			return tea.KeyMsg{Type: tea.KeyEnter}
		}
	}
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(s)}
}

func send(m Model, k string) Model {
	next, _ := m.Update(key(k))
	return next.(Model)
}

func TestCursorMovesWithinBounds(t *testing.T) {
	m := testModel(t)
	if m.cursor != 0 {
		t.Fatalf("cursor starts at %d", m.cursor)
	}
	// Up at the top must not wrap or go negative: a negative index panics on
	// the next toggle.
	m = send(m, "up")
	if m.cursor != 0 {
		t.Errorf("cursor went to %d above the first row", m.cursor)
	}
	m = send(m, "down")
	if m.cursor != 1 {
		t.Errorf("cursor = %d after down, want 1", m.cursor)
	}
	m = send(m, "down")
	if m.cursor != 1 {
		t.Errorf("cursor = %d past the last row, want 1", m.cursor)
	}
}

func TestSpaceTogglesTheGroupUnderTheCursor(t *testing.T) {
	m := testModel(t)
	m = send(m, " ")
	if m.plan.Groups[0].Selected {
		t.Error("space did not deselect the first group")
	}
	if !m.plan.Groups[1].Selected {
		t.Error("space changed a group that was not under the cursor")
	}
	m = send(m, " ")
	if !m.plan.Groups[0].Selected {
		t.Error("space did not reselect")
	}
}

func TestSelectAllAndNone(t *testing.T) {
	m := testModel(t)
	m = send(m, "n")
	for _, g := range m.plan.Groups {
		if g.Selected {
			t.Error("n must clear every selection")
		}
	}
	m = send(m, "a")
	for _, g := range m.plan.Groups {
		if !g.Selected {
			t.Error("a must select everything")
		}
	}
}

func TestEnterWithNothingSelectedStaysOnTheSelectScreen(t *testing.T) {
	// Starting an empty run would show an empty summary and read as a failure.
	m := testModel(t)
	m = send(m, "n")
	m = send(m, "enter")
	if m.Screen() != ScreenSelect {
		t.Errorf("screen = %v, want select", m.Screen())
	}
}

func TestEnterStartsTheInstall(t *testing.T) {
	m := testModel(t)
	next, cmd := m.Update(key("enter"))
	m = next.(Model)
	if m.Screen() != ScreenInstall {
		t.Fatalf("screen = %v, want install", m.Screen())
	}
	if cmd == nil {
		t.Fatal("entering the install screen must return a command that applies the first action")
	}
}

func TestTheRunAppliesEveryActionAndFinishes(t *testing.T) {
	m := testModel(t)
	next, cmd := m.Update(key("enter"))
	m = next.(Model)

	// Drive the loop the way bubbletea would, without a terminal.
	for i := 0; i < 10 && cmd != nil; i++ {
		msg := cmd()
		if _, ok := msg.(doneMsg); ok {
			next, _ = m.Update(msg)
			m = next.(Model)
			break
		}
		next, cmd = m.Update(msg)
		m = next.(Model)
	}

	if m.Screen() != ScreenDone {
		t.Errorf("screen = %v, want done", m.Screen())
	}
	if got, want := len(m.Results()), 2; got != want {
		t.Errorf("results = %d, want %d", got, want)
	}
	if len(m.Errs()) != 0 {
		t.Errorf("unexpected errors: %v", m.Errs())
	}
	for _, r := range m.Results() {
		if _, err := os.Lstat(r.Action.Dest); err != nil {
			t.Errorf("%s was not created: %v", r.Action.Label, err)
		}
	}
}

func TestQuitIsRefusedMidInstall(t *testing.T) {
	// Quitting here leaves the run half-applied with no summary explaining it.
	m := testModel(t)
	next, _ := m.Update(key("enter"))
	m = next.(Model)

	m = send(m, "q")
	if m.Quitting {
		t.Error("q must not quit while files are being written")
	}
}

func TestQuitWorksOnTheSelectScreen(t *testing.T) {
	m := testModel(t)
	m = send(m, "q")
	if !m.Quitting {
		t.Error("q must quit from the select screen")
	}
}

func TestSelectViewShowsTheEssentials(t *testing.T) {
	m := testModel(t)
	v := m.View()
	for _, want := range []string{"Group One", "Group Two", "first", "macOS", "items selected"} {
		if !strings.Contains(v, want) {
			t.Errorf("select view is missing %q", want)
		}
	}
}

func TestUnavailableGroupsAreShownWithAReason(t *testing.T) {
	// Hiding them makes a Windows user wonder what they are missing.
	m := testModel(t)
	m.Unavailable = []UnavailableGroup{{Label: "Terminal environment", Reason: "not available on Windows"}}
	v := m.View()
	if !strings.Contains(v, "Terminal environment") {
		t.Error("an unavailable group must still be listed")
	}
	if !strings.Contains(v, "not available on Windows") {
		t.Error("an unavailable group must say why")
	}
}

func TestDryRunIsAnnouncedBeforeAnythingHappens(t *testing.T) {
	m := testModel(t)
	m.DryRun = true
	if !strings.Contains(m.View(), "dry run") {
		t.Error("a dry run must be visible on the first screen, not just at the end")
	}
}

func TestDoneViewNamesTheBackupDirectory(t *testing.T) {
	// The one thing the user may need to act on: their old config is in there.
	repo, home := t.TempDir(), t.TempDir()
	src := filepath.Join(repo, "a")
	if err := os.WriteFile(src, []byte("new"), 0o644); err != nil {
		t.Fatal(err)
	}
	dest := filepath.Join(home, ".a")
	if err := os.WriteFile(dest, []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}

	p := &plan.Plan{Groups: []plan.Group{{ID: "g", Label: "G", Selected: true, Actions: []plan.Action{
		{Source: src, Dest: dest, Label: "~/.a"},
	}}}}
	r := install.New(install.Options{Home: home, Symlinks: true})
	m := NewModel(p, platform.Platform{OS: "darwin"}, r, true, false)

	next, cmd := m.Update(key("enter"))
	m = next.(Model)
	for i := 0; i < 10 && cmd != nil; i++ {
		msg := cmd()
		next, cmd = m.Update(msg)
		m = next.(Model)
		if m.Screen() == ScreenDone {
			break
		}
	}

	v := m.View()
	if !strings.Contains(v, "moved to") {
		t.Error("the summary must say that existing files were moved")
	}
	if !strings.Contains(v, ".dotfiles-backup") {
		t.Error("the summary must name the backup directory")
	}
}

func TestWindowSizeIsHonoured(t *testing.T) {
	// A narrow terminal must not make the progress bar wrap.
	m := testModel(t)
	next, _ := m.Update(tea.WindowSizeMsg{Width: 30, Height: 20})
	m = next.(Model)
	if m.width != 30 {
		t.Errorf("width = %d, want 30", m.width)
	}
}
