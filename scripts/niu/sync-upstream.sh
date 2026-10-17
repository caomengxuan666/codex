#!/usr/bin/env bash
# Keep this fork in step with upstream openai/codex.
#
# The fork's delta is deliberately small (a shell type, its detection, parsing
# and safety rules, and the sandbox plumbing). The job of this script is to make
# that delta visible, reproducible, and provably applied to a current upstream.
#
# Subcommands:
#   pin      record the upstream commit this fork is currently based on
#   drift    show how far behind upstream main is, and what changed upstream
#   rebase   fetch upstream and replay the fork's commits on top of it
#   export   write the delta to patches/niu/ as a mail-formatted series
#   check    apply the exported patches to a pristine upstream checkout
#            (git apply -3) and report conflicts without touching this tree
#
# Typical loop after an upstream release:
#   scripts/niu/sync-upstream.sh drift
#   scripts/niu/sync-upstream.sh rebase
#   scripts/niu/sync-upstream.sh export
#   scripts/niu/sync-upstream.sh check
#   scripts/niu/sync-upstream.sh pin
#
# HTTP proxy: on networks where GitHub needs one, configure it once per clone,
# otherwise every fetch here fails with "remote helper 'https' aborted session":
#   git config http.proxy http://127.0.0.1:65532

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
PATCH_DIR="patches/niu"
PIN_FILE="patches/UPSTREAM"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

require_upstream() {
  git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 \
    || die "no '$UPSTREAM_REMOTE' remote; add it with: git remote add upstream https://github.com/openai/codex.git"
}

# Files where the fork changes behaviour upstream also changes. Conflicts here
# are expected, and a stale patch here is a safety problem rather than a
# cosmetic one: upstream keeps adding dangerous-command rules.
HOT_FILES=(
  codex-rs/shell-command/src/shell_detect.rs
  codex-rs/shell-command/src/bash.rs
  codex-rs/shell-command/src/parse_command.rs
  codex-rs/shell-command/src/command_safety/is_safe_command.rs
  codex-rs/shell-command/src/command_safety/is_dangerous_command.rs
)

cmd_fetch() {
  require_upstream
  echo "fetching $UPSTREAM_REMOTE/$UPSTREAM_BRANCH (no tags)"
  echo "note: the first fetch of this repository is large (hundreds of MB)."
  echo "      fetch again later and it is incremental."
  git fetch --no-tags "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"
  echo "now at $(git rev-parse --short "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")"
}

cmd_drift() {
  require_upstream
  # No fetch here on purpose: fetching this repository is a large operation, so
  # `fetch` is its own step. Compare against whatever upstream ref exists and
  # say how old it is.
  local when
  when="$(git show -s --format=%cI "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" 2>/dev/null || echo unknown)"
  echo "upstream $UPSTREAM_REMOTE/$UPSTREAM_BRANCH : $(git rev-parse --short "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")  (fetched object date: $when)"
  echo "branch   $BRANCH : $(git rev-parse --short HEAD)"
  echo "run 'scripts/niu/sync-upstream.sh fetch' first if that looks stale."
  echo
  echo "behind / ahead (upstream...HEAD):"
  git rev-list --left-right --count "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH...HEAD" | \
    while read -r behind ahead; do echo "  behind $behind, ahead $ahead"; done
  echo
  echo "commits upstream gained since the merge base:"
  # -n instead of `| head`: pipefail would abort the script on SIGPIPE.
  git log --oneline -n 15 "$(git merge-base HEAD "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
  echo
  echo "upstream commits touching this fork's hot files:"
  git log --oneline -n 15 "$(git merge-base HEAD "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" -- "${HOT_FILES[@]}"
  echo
  echo "this fork's delta:"
  git diff --stat "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH...HEAD" | tail -3
}

cmd_rebase() {
  require_upstream
  echo "fetching $UPSTREAM_REMOTE/$UPSTREAM_BRANCH (no tags; large on the first run)"
  git fetch --no-tags "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH"
  echo "replaying $(git rev-list --count "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH..HEAD") commit(s) onto $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
  git rebase "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
  echo "done. resolve conflicts file by file, then: scripts/niu/sync-upstream.sh export"
}

cmd_export() {
  mkdir -p "$PATCH_DIR"
  rm -f "$PATCH_DIR"/*.patch
  # Exclude patches/ from the series. It is metadata *about* the delta, not part
  # of it: including it makes the series self-referential (the commit that writes
  # these files is itself one of them, so the last file can never be reproduced)
  # and `check` can then only ever report a three-way merge rather than an exact
  # apply. Regenerate it locally with `export`/`pin` after applying the series.
  git format-patch --no-signature --zero-commit \
    --output-directory "$PATCH_DIR" "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH..HEAD" \
    -- . ':(exclude)patches' >/dev/null
  echo "wrote $(ls "$PATCH_DIR"/*.patch | wc -l) patch(es) to $PATCH_DIR"
  ls -1 "$PATCH_DIR"
}

cmd_check() {
  [ -d "$PATCH_DIR" ] || die "$PATCH_DIR does not exist; run export first"
  local work
  work="$(mktemp -d)"
  echo "pristine upstream checkout in $work"
  git worktree add --quiet --detach "$work/upstream" "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
  local status=0
  (
    cd "$work/upstream"
    if git apply --check "$REPO_ROOT/$PATCH_DIR"/*.patch 2>"$work/apply.log"; then
      echo "patches apply exactly to $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
    elif git apply -3 "$REPO_ROOT/$PATCH_DIR"/*.patch 2>>"$work/apply.log"; then
      echo "patches needed a three-way merge against $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
      echo "(same result a rebase would produce; review the diff below)"
    else
      echo "PATCH CONFLICT against $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
      status=1
      # --3way left the tree untouched (apply is atomic). Re-run with --reject so
      # the hunks that do fit land and the failures are enumerated per file.
      # --reject cannot be combined with --3way, so this is context-only.
      git apply --reject "$REPO_ROOT/$PATCH_DIR"/*.patch >>"$work/apply.log" 2>&1 || true
      local rejected
      rejected="$(find . -name '*.rej' -not -path './.git/*' | sed 's|^\./||' | sort)"
      if [ -n "$rejected" ]; then
        echo
        echo "hunks that no longer apply (each needs a manual rebase):"
        printf '  %s\n' $rejected
      fi
    fi
    # Files the patch touches that upstream moved or removed. These need the
    # patch re-targeted, not a merge conflict resolved.
    if grep -E 'No such file or directory|does not exist in index' "$work/apply.log" >/dev/null 2>&1; then
      echo
      echo "targets that no longer exist upstream:"
      grep -E 'No such file or directory|does not exist in index' "$work/apply.log" | sed 's/^/  /'
    fi
    local conflicted
    conflicted="$(git ls-files -u | cut -f2 | sort -u)"
    if [ -n "$conflicted" ]; then
      echo
      echo "conflicted files (a rebase would stop on these):"
      printf '  %s\n' $conflicted
    fi
    echo
    echo "fork delta as far as it applied:"
    git diff --stat | tail -5
    exit $status
  ) || status=$?
  git worktree remove --force "$work/upstream" 2>/dev/null || true
  rm -rf "$work"
  return $status
}

cmd_pin() {
  require_upstream
  mkdir -p "$(dirname "$PIN_FILE")"
  local base
  base="$(git merge-base HEAD "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")"
  {
    echo "# Upstream commit this fork is based on."
    echo "# Refreshed by scripts/niu/sync-upstream.sh pin after every rebase."
    echo "repo=https://github.com/openai/codex"
    echo "branch=$UPSTREAM_BRANCH"
    echo "commit=$base"
    echo "commit_date=$(git show -s --format=%cI "$base")"
    echo "fork_commits=$(git rev-list --count "$base..HEAD")"
  } > "$PIN_FILE"
  cat "$PIN_FILE"
}

case "${1:-}" in
  pin)    cmd_pin ;;
  fetch)  cmd_fetch ;;
  drift)  cmd_drift ;;
  rebase) cmd_rebase ;;
  export) cmd_export ;;
  check)  cmd_check ;;
  *) sed -n '2,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
