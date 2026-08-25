// Package platform detects the machine the installer is running on and what
// it can actually do there.
//
// Two distinctions drive everything downstream:
//
//   - Unix vs Windows decides which manifest groups apply at all. The terminal
//     environment (tmux, yazi, Ghostty, zsh) has no Windows-native equivalent.
//   - symlink vs copy decides how files are installed. Windows can create
//     symlinks only under Developer Mode or elevation, so the installer probes
//     rather than assuming, and falls back to copying.
//
// WSL is reported separately because it is a Windows machine that takes the
// Unix path, and a user staring at the summary deserves to know why.
package platform

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// Platform describes the detected environment.
type Platform struct {
	OS     string // runtime.GOOS
	Arch   string
	WSL    bool
	Distro string // best-effort pretty name on Linux
}

// Detect inspects the running machine.
func Detect() Platform {
	p := Platform{OS: runtime.GOOS, Arch: runtime.GOARCH}
	if p.OS == "linux" {
		p.WSL = detectWSL("/proc/version")
		p.Distro = detectDistro("/etc/os-release")
	}
	return p
}

// Unix reports whether this machine gets the Unix install: symlinks into
// $HOME, and the terminal groups offered. WSL counts as Unix — that is the
// entire reason someone installs these dotfiles from Windows.
func (p Platform) Unix() bool { return p.OS != "windows" }

// Display is the one-line environment description shown at the top of the TUI.
func (p Platform) Display() string {
	switch p.OS {
	case "darwin":
		return fmt.Sprintf("macOS (%s)", p.Arch)
	case "windows":
		return fmt.Sprintf("Windows (%s)", p.Arch)
	case "linux":
		name := p.Distro
		if name == "" {
			name = "Linux"
		}
		if p.WSL {
			return fmt.Sprintf("WSL — %s (%s)", name, p.Arch)
		}
		return fmt.Sprintf("%s (%s)", name, p.Arch)
	default:
		return fmt.Sprintf("%s (%s)", p.OS, p.Arch)
	}
}

// InstallStyle explains, in the user's terms, what installing will do. The
// distinction matters to them: a symlinked config picks up repo edits live,
// a copied one needs the installer run again.
func (p Platform) InstallStyle(symlinks bool) string {
	if symlinks {
		return "symlinked — edits in the repo apply immediately"
	}
	return "copied — re-run the installer after changing the repo"
}

// SupportsSymlinks probes whether a symlink can actually be created in dir.
//
// It probes rather than checking the OS, because the answer on Windows depends
// on Developer Mode and on elevation, neither of which is knowable from GOOS.
// The probe cleans up after itself; a leftover would collide on the next call
// and report a false negative.
func (p Platform) SupportsSymlinks(dir string) bool {
	target := filepath.Join(dir, ".dotfiles-symlink-probe-target")
	link := filepath.Join(dir, ".dotfiles-symlink-probe-link")

	// Both are removed up front too: a probe interrupted mid-run (Ctrl-C, a
	// crash) would otherwise poison every later attempt.
	_ = os.Remove(link)
	_ = os.Remove(target)

	if err := os.WriteFile(target, []byte("probe"), 0o644); err != nil {
		return false
	}
	defer os.Remove(target)

	if err := os.Symlink(target, link); err != nil {
		return false
	}
	defer os.Remove(link)

	return true
}

// detectWSL reads a kernel version string. Microsoft's WSL2 kernels carry
// "microsoft" in the release, which is the standard detection method and works
// without shelling out.
func detectWSL(procVersion string) bool {
	b, err := os.ReadFile(procVersion)
	if err != nil {
		return false
	}
	return strings.Contains(strings.ToLower(string(b)), "microsoft")
}

// detectDistro pulls PRETTY_NAME out of os-release. Cosmetic only: a failure
// degrades to the generic "Linux" rather than blocking the install.
func detectDistro(osRelease string) string {
	b, err := os.ReadFile(osRelease)
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(b), "\n") {
		if v, ok := strings.CutPrefix(line, "PRETTY_NAME="); ok {
			return strings.Trim(strings.TrimSpace(v), `"`)
		}
	}
	return ""
}
