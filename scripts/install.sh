#!/usr/bin/env sh
# Bootstrap the dotfiles installer.
#
#   curl -fsSL https://raw.githubusercontent.com/alvaroofernaandez/dotfiles/main/scripts/install.sh | sh
#
# Clones (or updates) the repository, fetches the installer binary for this
# platform, and hands over to its TUI.
#
# POSIX sh, not bash: this is the one file that runs before anything is
# installed, so it cannot assume the shell the rest of the repo configures. It
# also cannot assume Go — the binary is downloaded, and building from source is
# only the fallback.
set -eu

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/alvaroofernaandez/dotfiles.git}"
REPO_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
RELEASE_BASE="${DOTFILES_RELEASE_BASE:-https://github.com/alvaroofernaandez/dotfiles/releases/latest/download}"

# Tokyo Night, degraded to plain text when stdout is not a terminal — piping
# this script into a log should not fill it with escape sequences.
if [ -t 1 ]; then
  C_BLUE='\033[38;2;122;162;247m'
  C_CYAN='\033[38;2;125;207;255m'
  C_GREEN='\033[38;2;158;206;106m'
  C_RED='\033[38;2;247;118;142m'
  C_DIM='\033[38;2;86;95;137m'
  C_OFF='\033[0m'
else
  C_BLUE='' C_CYAN='' C_GREEN='' C_RED='' C_DIM='' C_OFF=''
fi

say()  { printf "%b%s%b\n" "$C_DIM" "$1" "$C_OFF"; }
step() { printf "%b▸%b %s\n" "$C_BLUE" "$C_OFF" "$1"; }
ok()   { printf "%b✓%b %s\n" "$C_GREEN" "$C_OFF" "$1"; }
die()  { printf "%b✗%b %s\n" "$C_RED" "$C_OFF" "$1" >&2; exit 1; }

banner() {
  printf "\n%b  dotfiles%b %b· installer%b\n" "$C_CYAN" "$C_OFF" "$C_DIM" "$C_OFF"
  printf "%b  ────────────────────────%b\n\n" "$C_DIM" "$C_OFF"
}

need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"; }

detect_platform() {
  os="$(uname -s)"
  case "$os" in
    Darwin) OS=darwin ;;
    Linux)  OS=linux ;;
    MINGW* | MSYS* | CYGWIN*) OS=windows ;;
    *) die "unsupported operating system: $os" ;;
  esac

  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) ARCH=amd64 ;;
    arm64 | aarch64) ARCH=arm64 ;;
    *) die "unsupported architecture: $arch" ;;
  esac

  EXT=""
  [ "$OS" = "windows" ] && EXT=".exe"

  # Worth naming: on WSL the Unix path is taken even though the machine is a
  # Windows box, and someone reading the output should see why.
  if [ "$OS" = "linux" ] && grep -qi microsoft /proc/version 2>/dev/null; then
    say "detected WSL — installing the Unix environment"
  fi
}

clone_or_update() {
  if [ -d "$REPO_DIR/.git" ]; then
    step "Updating $REPO_DIR"
    # A dirty tree is left alone rather than stashed: silently moving someone's
    # uncommitted work is not this script's call to make.
    if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
      say "local changes present — skipping pull"
    else
      git -C "$REPO_DIR" pull --ff-only --quiet || die "could not fast-forward $REPO_DIR"
    fi
  else
    step "Cloning into $REPO_DIR"
    git clone --quiet "$REPO_URL" "$REPO_DIR" || die "clone failed"
  fi
  ok "Repository ready"
}

fetch_binary() {
  BIN="$REPO_DIR/bin/dotfiles-installer$EXT"
  mkdir -p "$REPO_DIR/bin"

  asset="dotfiles-installer-$OS-$ARCH$EXT"
  step "Fetching installer for $OS/$ARCH"

  if curl -fsSL "$RELEASE_BASE/$asset" -o "$BIN.tmp" 2>/dev/null; then
    chmod +x "$BIN.tmp"
    mv "$BIN.tmp" "$BIN"
    ok "Installer downloaded"
    return 0
  fi

  rm -f "$BIN.tmp"
  say "no published binary for this platform"

  # Falling back to a source build rather than failing: a new platform, or a
  # release that has not been cut yet, should not block someone entirely.
  if command -v go >/dev/null 2>&1; then
    step "Building from source"
    (cd "$REPO_DIR" && go build -trimpath \
      -ldflags "-s -w -X main.version=$(git -C "$REPO_DIR" describe --tags --always 2>/dev/null || echo dev)" \
      -o "$BIN" ./cmd/dotfiles-installer) || die "build failed"
    ok "Installer built"
    return 0
  fi

  die "no binary available and Go is not installed — install Go, or run $REPO_DIR/install.sh instead"
}

main() {
  banner
  need git
  need curl
  detect_platform
  clone_or_update
  fetch_binary

  printf "\n"
  # exec, so the TUI owns the terminal and signals reach it directly rather
  # than being swallowed by this script.
  exec "$BIN" "$@"
}

main "$@"
