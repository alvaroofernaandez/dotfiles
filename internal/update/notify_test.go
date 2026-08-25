package update

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestNoticeIsSilentWhenCurrent(t *testing.T) {
	// The common case by far. A tool that prints something on every run when
	// there is nothing to say trains people to ignore it.
	n := Notice{Current: "1.2.3", Latest: "1.2.3", Command: "x"}
	if got := n.String(); got != "" {
		t.Errorf("String() = %q, want empty", got)
	}
}

func TestNoticeIsSilentWithNoAnswer(t *testing.T) {
	// Offline, proxied, or DNS-less: say nothing rather than something alarming.
	n := Notice{Current: "1.2.3", Latest: "", Command: "x"}
	if got := n.String(); got != "" {
		t.Errorf("String() = %q, want empty", got)
	}
}

func TestNoticeNamesBothVersionsAndTheCommand(t *testing.T) {
	n := Notice{Current: "1.2.3", Latest: "1.3.0", Command: "npm update -g pkg"}
	got := n.String()
	for _, want := range []string{"1.2.3", "1.3.0", "npm update -g pkg"} {
		if !strings.Contains(got, want) {
			t.Errorf("String() = %q, missing %q", got, want)
		}
	}
}

func TestCheckLatestParsesTheRegistry(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// The abbreviated document must be requested: the full one is megabytes.
		if got := r.Header.Get("Accept"); !strings.Contains(got, "install-v1") {
			t.Errorf("Accept = %q, want the abbreviated registry document", got)
		}
		w.Write([]byte(`{"version":"2.0.1"}`))
	}))
	defer srv.Close()

	n := checkAt(context.Background(), srv.URL, "1.0.0")
	if n.Latest != "2.0.1" {
		t.Errorf("Latest = %q, want 2.0.1", n.Latest)
	}
}

func TestCheckLatestSurvivesEveryFailure(t *testing.T) {
	// Each of these must degrade to silence, never to an error the installer
	// has to surface. Being offline cannot stop someone installing dotfiles.
	cases := map[string]http.HandlerFunc{
		"500":          func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(500) },
		"404":          func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(404) },
		"garbage body": func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("<html>")) },
		"empty body":   func(w http.ResponseWriter, _ *http.Request) {},
	}
	for name, h := range cases {
		srv := httptest.NewServer(h)
		n := checkAt(context.Background(), srv.URL, "1.0.0")
		if n.String() != "" {
			t.Errorf("%s produced a notice: %q", name, n.String())
		}
		srv.Close()
	}

	// An unreachable host, which is what being offline looks like.
	n := checkAt(context.Background(), "http://127.0.0.1:1/nope", "1.0.0")
	if n.String() != "" {
		t.Errorf("unreachable host produced a notice: %q", n.String())
	}
}

func TestCheckLatestHonoursContextCancellation(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		time.Sleep(2 * time.Second)
	}))
	defer srv.Close()

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	done := make(chan struct{})
	go func() {
		checkAt(ctx, srv.URL, "1.0.0")
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Error("a cancelled context did not abort the check")
	}
}

func TestShouldCheckHonoursTheOptOut(t *testing.T) {
	// Some people do not want a tool touching the network. That is legitimate
	// and must be honoured before anything else, including the cache.
	t.Setenv("DOTFILES_NO_UPDATE_CHECK", "1")
	if ShouldCheck(time.Now()) {
		t.Error("DOTFILES_NO_UPDATE_CHECK was ignored")
	}
}

func TestShouldCheckBacksOffWithinTheInterval(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", dir)
	t.Setenv("HOME", dir) // macOS derives the cache dir from HOME

	now := time.Now()
	if !ShouldCheck(now) {
		t.Fatal("the first check must run")
	}
	if ShouldCheck(now.Add(time.Hour)) {
		t.Error("checked again an hour later; the interval is a day")
	}
}

func TestShouldCheckRecordsTheAttemptBeforeChecking(t *testing.T) {
	// Touched before the request, not after: if the network hangs and the user
	// interrupts, the next run should back off rather than hang again.
	dir := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", dir)
	t.Setenv("HOME", dir)

	ShouldCheck(time.Now())

	var found bool
	filepath.Walk(dir, func(p string, info os.FileInfo, err error) error {
		if err == nil && info != nil && !info.IsDir() && strings.Contains(p, "last-update-check") {
			found = true
		}
		return nil
	})
	if !found {
		t.Error("no timestamp was written")
	}
}

func TestUpdateCommandMatchesTheInstallMethod(t *testing.T) {
	// Telling someone to run npm when they installed with curl is worse than
	// saying nothing at all.
	if got := commandFor("/usr/local/lib/node_modules/@scope/pkg/bin/x"); !strings.Contains(got, "npm") {
		t.Errorf("a node_modules path should suggest npm, got %q", got)
	}
	if got := commandFor("/Users/x/.dotfiles/bin/dotfiles-installer"); strings.Contains(got, "npm") {
		t.Errorf("a repo path should not suggest npm, got %q", got)
	}
}
