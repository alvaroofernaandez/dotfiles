// Package ui renders the installer.
//
// The palette is Tokyo Night (the "Night" variant), used at its published hex
// values rather than approximated, so the installer sits in the same visual
// family as the editor and terminal configs this repository installs.
package ui

import "github.com/charmbracelet/lipgloss"

// Tokyo Night — Night variant. Names follow the upstream theme so a value can
// be checked against it directly instead of guessed at.
const (
	ColorBG        = "#1a1b26" // canvas
	ColorBGDark    = "#16161e" // recessed surfaces
	ColorBGHigh    = "#292e42" // selected row
	ColorFG        = "#c0caf5" // primary text
	ColorFGDark    = "#a9b1d6" // secondary text
	ColorComment   = "#565f89" // de-emphasised text
	ColorBlue      = "#7aa2f7" // primary accent
	ColorCyan      = "#7dcfff" // headings
	ColorMagenta   = "#bb9af7" // selection marker
	ColorGreen     = "#9ece6a" // success
	ColorYellow    = "#e0af68" // warning, backups
	ColorOrange    = "#ff9e64" // emphasis
	ColorRed       = "#f7768e" // failure
	ColorTerminal3 = "#414868" // borders
)

// Theme carries every style the views use. It is a struct rather than a set of
// package-level vars so tests can build one without a terminal attached.
type Theme struct {
	Title       lipgloss.Style
	Subtitle    lipgloss.Style
	Heading     lipgloss.Style
	Body        lipgloss.Style
	Muted       lipgloss.Style
	Selected    lipgloss.Style
	Marker      lipgloss.Style
	Checked     lipgloss.Style
	Unchecked   lipgloss.Style
	Success     lipgloss.Style
	Warning     lipgloss.Style
	Failure     lipgloss.Style
	Box         lipgloss.Style
	Key         lipgloss.Style
	Bar         lipgloss.Style
	BarEmpty    lipgloss.Style
	Unavailable lipgloss.Style
}

// NewTheme builds the Tokyo Night theme.
//
// Nothing sets a background colour except the selected row. A TUI that paints
// its own canvas fights the user's terminal — and looks broken in any theme but
// the one it assumed. Foreground colours alone read correctly on both.
func NewTheme() Theme {
	return Theme{
		Title:    lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(ColorCyan)),
		Subtitle: lipgloss.NewStyle().Foreground(lipgloss.Color(ColorFGDark)),
		Heading:  lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(ColorBlue)),
		Body:     lipgloss.NewStyle().Foreground(lipgloss.Color(ColorFG)),
		Muted:    lipgloss.NewStyle().Foreground(lipgloss.Color(ColorComment)),

		Selected: lipgloss.NewStyle().
			Foreground(lipgloss.Color(ColorFG)).
			Background(lipgloss.Color(ColorBGHigh)).
			Bold(true),
		Marker:    lipgloss.NewStyle().Foreground(lipgloss.Color(ColorMagenta)).Bold(true),
		Checked:   lipgloss.NewStyle().Foreground(lipgloss.Color(ColorGreen)).Bold(true),
		Unchecked: lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTerminal3)),

		Success: lipgloss.NewStyle().Foreground(lipgloss.Color(ColorGreen)),
		Warning: lipgloss.NewStyle().Foreground(lipgloss.Color(ColorYellow)),
		Failure: lipgloss.NewStyle().Foreground(lipgloss.Color(ColorRed)).Bold(true),

		Box: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color(ColorTerminal3)).
			Padding(0, 1),

		Key:      lipgloss.NewStyle().Foreground(lipgloss.Color(ColorOrange)).Bold(true),
		Bar:      lipgloss.NewStyle().Foreground(lipgloss.Color(ColorBlue)),
		BarEmpty: lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTerminal3)),

		// Groups that do not apply to this machine are shown, not hidden: a
		// user on Windows should see that the terminal environment exists and
		// why it is unavailable, rather than wonder what is missing.
		Unavailable: lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTerminal3)).Italic(true),
	}
}

// ProgressBar renders a fixed-width bar. Width is a parameter because the
// installer must degrade on a narrow terminal rather than wrap into nonsense.
func (t Theme) ProgressBar(done, total, width int) string {
	if total <= 0 || width <= 0 {
		return ""
	}
	filled := done * width / total
	if filled > width {
		filled = width
	}
	bar := ""
	for i := 0; i < width; i++ {
		if i < filled {
			bar += t.Bar.Render("█")
		} else {
			bar += t.BarEmpty.Render("░")
		}
	}
	return bar
}
