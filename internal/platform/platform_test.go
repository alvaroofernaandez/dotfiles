package platform

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestDetectNamesTheOS(t *testing.T) {
	p := Detect()
	if p.OS != runtime.GOOS {
		t.Errorf("OS = %q, want %q", p.OS, runtime.GOOS)
	}
	if p.Display() == "" {
		t.Error("Display() must never be empty: the TUI shows it as the header")
	}
}

func TestDisplayNamesEachOS(t *testing.T) {
	cases := map[string]string{
		"darwin":  "macOS",
		"linux":   "Linux",
		"windows": "Windows",
	}
	for goos, want := range cases {
		p := Platform{OS: goos}
		if got := p.Display(); !strings.Contains(got, want) {
			t.Errorf("Display() for %s = %q, want it to contain %q", goos, got, want)
		}
	}
}

func TestDisplayMentionsWSL(t *testing.T) {
	// Worth surfacing: on WSL the installer takes the Unix path even though the
	// machine is a Windows box, and the user should see why.
	p := Platform{OS: "linux", WSL: true, Distro: "Ubuntu"}
	got := p.Display()
	if !strings.Contains(got, "WSL") {
		t.Errorf("Display() = %q, want it to mention WSL", got)
	}
	if !strings.Contains(got, "Ubuntu") {
		t.Errorf("Display() = %q, want it to name the distro", got)
	}
}

func TestUnixReportsTheInstallStyle(t *testing.T) {
	// This is what decides symlink vs copy, so it is worth pinning explicitly.
	cases := []struct {
		p    Platform
		unix bool
	}{
		{Platform{OS: "darwin"}, true},
		{Platform{OS: "linux"}, true},
		{Platform{OS: "linux", WSL: true}, true},
		{Platform{OS: "windows"}, false},
	}
	for _, c := range cases {
		if got := c.p.Unix(); got != c.unix {
			t.Errorf("Unix() for %+v = %v, want %v", c.p, got, c.unix)
		}
	}
}

func TestDetectWSLReadsProcVersion(t *testing.T) {
	dir := t.TempDir()

	microsoft := filepath.Join(dir, "version-wsl")
	if err := os.WriteFile(microsoft, []byte("Linux version 5.15.0-microsoft-standard-WSL2"), 0o644); err != nil {
		t.Fatal(err)
	}
	if !detectWSL(microsoft) {
		t.Error("a kernel string containing microsoft-standard-WSL2 must be detected as WSL")
	}

	plain := filepath.Join(dir, "version-plain")
	if err := os.WriteFile(plain, []byte("Linux version 6.8.0-generic (Ubuntu)"), 0o644); err != nil {
		t.Fatal(err)
	}
	if detectWSL(plain) {
		t.Error("a stock kernel string must not be detected as WSL")
	}

	// A missing /proc/version is the normal case on macOS and Windows. It must
	// read as "not WSL" rather than blowing up.
	if detectWSL(filepath.Join(dir, "does-not-exist")) {
		t.Error("a missing file must not be detected as WSL")
	}
}

func TestSupportsSymlinksIsTrueOnUnix(t *testing.T) {
	// On Unix this is unconditional. On Windows it is a real probe, because
	// symlink creation needs Developer Mode or elevation — which is exactly why
	// the installer falls back to copying there.
	p := Platform{OS: runtime.GOOS}
	if p.Unix() && !p.SupportsSymlinks(t.TempDir()) {
		t.Error("symlinks must be reported as supported on Unix")
	}
}

func TestSupportsSymlinksProbesRealDirectory(t *testing.T) {
	// The probe must clean up after itself: leaving the test symlink behind
	// would collide on the next run and report a false negative.
	dir := t.TempDir()
	p := Platform{OS: runtime.GOOS}
	_ = p.SupportsSymlinks(dir)
	_ = p.SupportsSymlinks(dir)

	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Errorf("probe left %d entries behind: %v", len(entries), entries)
	}
}

func TestInstallStyleDescribesItself(t *testing.T) {
	// Surfaced in the TUI so the user knows whether edits in the repo will show
	// up live (symlink) or need a re-run (copy).
	if got := (Platform{OS: "darwin"}).InstallStyle(true); !strings.Contains(strings.ToLower(got), "symlink") {
		t.Errorf("InstallStyle(true) = %q, want it to mention symlinks", got)
	}
	if got := (Platform{OS: "windows"}).InstallStyle(false); !strings.Contains(strings.ToLower(got), "cop") {
		t.Errorf("InstallStyle(false) = %q, want it to mention copying", got)
	}
}
