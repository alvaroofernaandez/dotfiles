package ui

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/alvaroofernaandez/dotfiles/internal/install"
	"github.com/alvaroofernaandez/dotfiles/internal/plan"
	"github.com/alvaroofernaandez/dotfiles/internal/platform"
)

// Screen is which of the three views is showing.
type Screen int

const (
	ScreenSelect  Screen = iota // choose what to install
	ScreenInstall               // work in progress
	ScreenDone                  // summary
)

// UnavailableGroup is a manifest group that does not apply to this machine.
// They are shown rather than hidden: someone on Windows should see that the
// terminal environment exists and why it is not offered, instead of wondering
// what is missing.
type UnavailableGroup struct {
	Label  string
	Reason string
}

// appliedMsg reports one finished action back into the update loop.
type appliedMsg struct {
	result install.Result
	err    error
}

// doneMsg marks the end of the run.
type doneMsg struct{}

// Model is the installer UI.
type Model struct {
	theme    Theme
	platform platform.Platform
	plan     *plan.Plan
	runner   *install.Runner

	Unavailable []UnavailableGroup
	Symlinks    bool
	DryRun      bool

	screen Screen
	cursor int

	queue   []plan.Action
	index   int
	results []install.Result
	errs    []error

	width int
	// Quitting records a deliberate exit, so main can tell "the user pressed q"
	// apart from "the install finished".
	Quitting bool
}

// NewModel builds the initial state.
func NewModel(p *plan.Plan, pf platform.Platform, r *install.Runner, symlinks, dryRun bool) Model {
	return Model{
		theme:    NewTheme(),
		platform: pf,
		plan:     p,
		runner:   r,
		Symlinks: symlinks,
		DryRun:   dryRun,
		screen:   ScreenSelect,
		width:    80,
	}
}

// Screen exposes the current view, for tests and for main's exit code.
func (m Model) Screen() Screen { return m.screen }

// Results exposes what was applied.
func (m Model) Results() []install.Result { return m.results }

// Errs exposes failures. A non-empty slice means a non-zero exit.
func (m Model) Errs() []error { return m.errs }

func (m Model) Init() tea.Cmd { return nil }

// Update handles one message.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		return m, nil

	case tea.KeyMsg:
		return m.handleKey(msg)

	case appliedMsg:
		if msg.err != nil {
			m.errs = append(m.errs, msg.err)
		} else {
			m.results = append(m.results, msg.result)
		}
		m.index++
		return m, m.applyNext()

	case doneMsg:
		m.screen = ScreenDone
		return m, nil
	}
	return m, nil
}

func (m Model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		// Quitting mid-install would leave the run half-applied with no
		// summary, so it is only offered where it is safe.
		if m.screen != ScreenInstall {
			m.Quitting = true
			return m, tea.Quit
		}
		return m, nil
	}

	switch m.screen {
	case ScreenSelect:
		return m.handleSelectKey(msg)
	case ScreenDone:
		if msg.String() == "enter" || msg.String() == "esc" {
			m.Quitting = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m Model) handleSelectKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down", "j":
		if m.cursor < len(m.plan.Groups)-1 {
			m.cursor++
		}
	case " ", "x":
		if len(m.plan.Groups) > 0 {
			m.plan.Groups[m.cursor].Selected = !m.plan.Groups[m.cursor].Selected
		}
	case "a":
		for i := range m.plan.Groups {
			m.plan.Groups[i].Selected = true
		}
	case "n":
		for i := range m.plan.Groups {
			m.plan.Groups[i].Selected = false
		}
	case "enter":
		m.queue = m.plan.SelectedActions()
		// Nothing selected is not an error, but starting an empty run and
		// showing an empty summary would be confusing. Stay put instead.
		if len(m.queue) == 0 {
			return m, nil
		}
		m.screen = ScreenInstall
		m.index = 0
		return m, m.applyNext()
	}
	return m, nil
}

// applyNext applies one action per cycle, so the UI repaints between them and
// the progress bar actually moves. Doing the whole run in one command would
// freeze the frame until it finished.
func (m Model) applyNext() tea.Cmd {
	if m.index >= len(m.queue) {
		return func() tea.Msg { return doneMsg{} }
	}
	action := m.queue[m.index]
	runner := m.runner
	return func() tea.Msg {
		res, err := runner.Apply(action)
		return appliedMsg{result: res, err: err}
	}
}

// View renders the current screen.
func (m Model) View() string {
	switch m.screen {
	case ScreenInstall:
		return m.viewInstall()
	case ScreenDone:
		return m.viewDone()
	default:
		return m.viewSelect()
	}
}

func (m Model) header() string {
	var b strings.Builder
	b.WriteString(m.theme.Title.Render("dotfiles installer"))
	b.WriteString("\n")
	b.WriteString(m.theme.Subtitle.Render(m.platform.Display()))
	if m.DryRun {
		b.WriteString(m.theme.Warning.Render("  ·  dry run: nothing will be written"))
	}
	b.WriteString("\n")
	b.WriteString(m.theme.Muted.Render(m.platform.InstallStyle(m.Symlinks)))
	b.WriteString("\n\n")
	return b.String()
}

func (m Model) viewSelect() string {
	var b strings.Builder
	b.WriteString(m.header())

	selected := 0
	for _, g := range m.plan.Groups {
		if g.Selected {
			selected += len(g.Actions)
		}
	}

	b.WriteString(m.theme.Heading.Render("What to install"))
	b.WriteString("\n\n")

	for i, g := range m.plan.Groups {
		box := m.theme.Unchecked.Render("[ ]")
		if g.Selected {
			box = m.theme.Checked.Render("[x]")
		}
		marker := "  "
		if i == m.cursor {
			marker = m.theme.Marker.Render("▸ ")
		}

		line := fmt.Sprintf("%s %-22s %s", box, g.Label,
			m.theme.Muted.Render(fmt.Sprintf("%d items", len(g.Actions))))
		if i == m.cursor {
			line = m.theme.Selected.Render(line)
		}
		b.WriteString(marker + line + "\n")
		if g.Detail != "" {
			b.WriteString("      " + m.theme.Muted.Render(g.Detail) + "\n")
		}
	}

	for _, u := range m.Unavailable {
		b.WriteString("  " + m.theme.Unavailable.Render(fmt.Sprintf("[-] %-22s %s", u.Label, u.Reason)) + "\n")
	}

	b.WriteString("\n")
	b.WriteString(m.theme.Body.Render(fmt.Sprintf("%d items selected", selected)))
	b.WriteString("\n\n")
	b.WriteString(m.help(
		"↑/↓", "move", "space", "toggle", "a", "all", "n", "none", "enter", "install", "q", "quit",
	))
	return b.String()
}

func (m Model) viewInstall() string {
	var b strings.Builder
	b.WriteString(m.header())

	done, total := m.index, len(m.queue)
	width := m.width - 20
	if width > 48 {
		width = 48
	}
	if width < 10 {
		width = 10
	}

	b.WriteString(m.theme.Heading.Render("Installing"))
	b.WriteString("\n\n")
	b.WriteString(m.theme.ProgressBar(done, total, width))
	b.WriteString(m.theme.Body.Render(fmt.Sprintf("  %d/%d", done, total)))
	b.WriteString("\n\n")

	// The last few lines only: a full log scrolls the frame and hides the bar.
	start := len(m.results) - 6
	if start < 0 {
		start = 0
	}
	for _, r := range m.results[start:] {
		b.WriteString("  " + m.statusLine(r) + "\n")
	}
	return b.String()
}

func (m Model) viewDone() string {
	var b strings.Builder
	b.WriteString(m.header())

	counts := map[install.Status]int{}
	backups := 0
	for _, r := range m.results {
		counts[r.Status]++
		if r.Backup != "" {
			backups++
		}
	}

	if len(m.errs) > 0 {
		b.WriteString(m.theme.Failure.Render(fmt.Sprintf("Finished with %d error(s)", len(m.errs))))
	} else if m.DryRun {
		b.WriteString(m.theme.Warning.Render("Dry run complete — nothing was written"))
	} else {
		b.WriteString(m.theme.Success.Render("Done"))
	}
	b.WriteString("\n\n")

	for _, s := range []install.Status{install.StatusLinked, install.StatusCopied, install.StatusAlready, install.StatusWould} {
		if counts[s] > 0 {
			b.WriteString(m.theme.Body.Render(fmt.Sprintf("  %-18s %d\n", s.String(), counts[s])))
		}
	}

	// Named explicitly, because it is the one thing the user may need to act
	// on: their previous config is in there, not gone.
	if backups > 0 {
		b.WriteString("\n")
		b.WriteString(m.theme.Warning.Render(fmt.Sprintf("  %d existing file(s) moved to:", backups)))
		b.WriteString("\n  " + m.theme.Muted.Render(m.runner.BackupRoot()) + "\n")
	}

	for _, err := range m.errs {
		b.WriteString("\n  " + m.theme.Failure.Render(err.Error()))
	}

	b.WriteString("\n\n")
	b.WriteString(m.help("enter", "close"))
	return b.String()
}

func (m Model) statusLine(r install.Result) string {
	style := m.theme.Success
	switch r.Status {
	case install.StatusAlready:
		style = m.theme.Muted
	case install.StatusWould:
		style = m.theme.Warning
	}
	line := fmt.Sprintf("%-40s %s", r.Action.Label, style.Render(r.Status.String()))
	if r.Backup != "" {
		line += m.theme.Warning.Render("  (backed up)")
	}
	return line
}

// help renders alternating key/description pairs.
func (m Model) help(pairs ...string) string {
	var parts []string
	for i := 0; i+1 < len(pairs); i += 2 {
		parts = append(parts, m.theme.Key.Render(pairs[i])+" "+m.theme.Muted.Render(pairs[i+1]))
	}
	return strings.Join(parts, m.theme.Muted.Render("  ·  "))
}
