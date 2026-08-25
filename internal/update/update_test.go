package update

import (
	"context"
	"strings"
	"testing"
)

// fakeGit replays canned answers and records what was asked, so the update
// logic can be exercised without a network or a clone.
type fakeGit struct {
	answers map[string]string
	errs    map[string]error
	calls   []string
}

func (f *fakeGit) Run(_ context.Context, args ...string) (string, error) {
	key := strings.Join(args, " ")
	f.calls = append(f.calls, key)
	if err, ok := f.errs[key]; ok {
		return "", err
	}
	return f.answers[key], nil
}

func (f *fakeGit) called(sub string) bool {
	for _, c := range f.calls {
		if strings.HasPrefix(c, sub) {
			return true
		}
	}
	return false
}

func cleanRepo() *fakeGit {
	return &fakeGit{answers: map[string]string{
		"rev-parse --short HEAD":             "abc1234",
		"status --porcelain":                 "",
		"fetch --quiet origin":               "",
		"rev-list --count HEAD..@{upstream}": "3",
		"rev-parse --short @{upstream}":      "def5678",
		"pull --ff-only --quiet":             "",
	}}
}

func TestCheckReportsHowFarBehind(t *testing.T) {
	g := cleanRepo()
	s, err := Check(context.Background(), g)
	if err != nil {
		t.Fatal(err)
	}
	if s.Behind != 3 {
		t.Errorf("Behind = %d, want 3", s.Behind)
	}
	if s.Current != "abc1234" || s.Latest != "def5678" {
		t.Errorf("revisions = %s..%s", s.Current, s.Latest)
	}
	if s.Updated {
		t.Error("Check must not report an update: it changes nothing")
	}
}

func TestCheckDoesNotModifyTheRepository(t *testing.T) {
	g := cleanRepo()
	if _, err := Check(context.Background(), g); err != nil {
		t.Fatal(err)
	}
	if g.called("pull") {
		t.Error("Check pulled")
	}
	if g.called("merge") || g.called("reset") {
		t.Error("Check modified the working tree")
	}
}

func TestPullFastForwardsWhenBehind(t *testing.T) {
	g := cleanRepo()
	s, err := Pull(context.Background(), g)
	if err != nil {
		t.Fatal(err)
	}
	if !s.Updated {
		t.Error("Updated = false after pulling 3 commits")
	}
	if !g.called("pull --ff-only") {
		t.Error("Pull must use --ff-only: an installer must not create merge commits")
	}
}

func TestPullIsANoopWhenUpToDate(t *testing.T) {
	g := cleanRepo()
	g.answers["rev-list --count HEAD..@{upstream}"] = "0"
	s, err := Pull(context.Background(), g)
	if err != nil {
		t.Fatal(err)
	}
	if s.Updated {
		t.Error("Updated = true with nothing to pull")
	}
	if g.called("pull") {
		t.Error("Pull ran git pull with nothing to pull")
	}
}

func TestPullRefusesToTouchADirtyTree(t *testing.T) {
	// Silently stashing someone's uncommitted work is exactly what an
	// installer must never do.
	g := cleanRepo()
	g.answers["status --porcelain"] = " M config/tmux/statusbar.sh"

	s, err := Pull(context.Background(), g)
	if err == nil {
		t.Fatal("expected an error for a dirty tree")
	}
	if !s.DirtyTree {
		t.Error("DirtyTree = false for a modified tree")
	}
	if g.called("pull") || g.called("stash") {
		t.Error("Pull touched a dirty repository")
	}
	if !strings.Contains(err.Error(), "uncommitted") {
		t.Errorf("the error should explain itself, got: %v", err)
	}
}

func TestMissingUpstreamIsNotAFailure(t *testing.T) {
	// A local clone with no upstream is a normal state, not something to abort
	// the whole installer over.
	g := cleanRepo()
	g.errs = map[string]error{
		"rev-list --count HEAD..@{upstream}": context.DeadlineExceeded,
	}
	s, err := Check(context.Background(), g)
	if err != nil {
		t.Fatalf("a missing upstream must not error: %v", err)
	}
	if s.Behind != 0 {
		t.Errorf("Behind = %d with no upstream, want 0", s.Behind)
	}
	if s.Latest != s.Current {
		t.Error("with no upstream, latest should fall back to current")
	}
}
