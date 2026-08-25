package ui

import (
	"strings"
	"testing"

	"github.com/charmbracelet/lipgloss"
)

func TestPaletteMatchesTokyoNight(t *testing.T) {
	// Pinned against the upstream Tokyo Night (Night) values. Colours drift when
	// they are eyeballed; this fails the moment one is edited by hand.
	want := map[string]string{
		"bg":      "#1a1b26",
		"bg_high": "#292e42",
		"fg":      "#c0caf5",
		"comment": "#565f89",
		"blue":    "#7aa2f7",
		"cyan":    "#7dcfff",
		"magenta": "#bb9af7",
		"green":   "#9ece6a",
		"yellow":  "#e0af68",
		"orange":  "#ff9e64",
		"red":     "#f7768e",
	}
	got := map[string]string{
		"bg":      ColorBG,
		"bg_high": ColorBGHigh,
		"fg":      ColorFG,
		"comment": ColorComment,
		"blue":    ColorBlue,
		"cyan":    ColorCyan,
		"magenta": ColorMagenta,
		"green":   ColorGreen,
		"yellow":  ColorYellow,
		"orange":  ColorOrange,
		"red":     ColorRed,
	}
	for name, w := range want {
		if got[name] != w {
			t.Errorf("%s = %s, want %s", name, got[name], w)
		}
	}
}

func TestOnlyTheSelectedRowPaintsABackground(t *testing.T) {
	// A TUI that paints its own canvas fights the user's terminal and looks
	// broken under any theme but the one it assumed.
	th := NewTheme()
	// An unset background reads back as NoColor{}, not nil.
	if bg := th.Body.GetBackground(); bg != (lipgloss.NoColor{}) {
		t.Errorf("Body must not set a background colour, got %v", bg)
	}
	if bg := th.Selected.GetBackground(); bg == (lipgloss.NoColor{}) {
		t.Error("Selected must set a background: it is what marks the cursor row")
	}
}

func TestProgressBarFillsProportionally(t *testing.T) {
	th := NewTheme()
	cases := []struct {
		done, total, width int
		wantFilled         int
	}{
		{0, 10, 10, 0},
		{5, 10, 10, 5},
		{10, 10, 10, 10},
		{3, 4, 8, 6},
	}
	for _, c := range cases {
		bar := th.ProgressBar(c.done, c.total, c.width)
		if got := strings.Count(bar, "█"); got != c.wantFilled {
			t.Errorf("ProgressBar(%d,%d,%d) filled %d, want %d", c.done, c.total, c.width, got, c.wantFilled)
		}
	}
}

func TestProgressBarNeverExceedsItsWidth(t *testing.T) {
	// done > total happens transiently if an action reports twice; the bar must
	// not spill past its box and corrupt the frame.
	th := NewTheme()
	bar := th.ProgressBar(20, 10, 10)
	if got := strings.Count(bar, "█"); got != 10 {
		t.Errorf("overfilled bar has %d cells, want 10", got)
	}
}

func TestProgressBarHandlesDegenerateInput(t *testing.T) {
	// A zero-width terminal or an empty plan must render nothing, not panic.
	th := NewTheme()
	if got := th.ProgressBar(0, 0, 10); got != "" {
		t.Errorf("zero total = %q, want empty", got)
	}
	if got := th.ProgressBar(1, 10, 0); got != "" {
		t.Errorf("zero width = %q, want empty", got)
	}
}
