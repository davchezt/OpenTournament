#!/usr/bin/env bash
set -euo pipefail

force=0

usage() {
    cat <<'EOF'
Usage: ./SetupContributor.sh [--force]

Configures Git LFS filters and the shared OpenTournament Git hooks for the
current clone.

--force  Replace a different repository-local core.hooksPath setting.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            force=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! command -v git >/dev/null 2>&1; then
    echo "Git was not found in PATH. Install Git and restart the terminal." >&2
    exit 1
fi

if ! git lfs version >/dev/null 2>&1; then
    echo "Git LFS is not installed or is not available in PATH." >&2
    echo "Install it from https://git-lfs.com/ and rerun this script." >&2
    exit 1
fi

if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]]; then
    echo "Run this script from inside an OpenTournament Git clone." >&2
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ ! -f ".githooks/pre-push" ]]; then
    echo "Missing .githooks/pre-push. Ensure this is a current OpenTournament clone." >&2
    exit 1
fi

if [[ ! -f ".lfsconfig" ]]; then
    echo "Missing .lfsconfig. Ensure this is a current OpenTournament clone." >&2
    exit 1
fi

existing_hooks_path="$(git config --local --get core.hooksPath || true)"

if [[ -n "$existing_hooks_path" && "$existing_hooks_path" != ".githooks" && "$force" -ne 1 ]]; then
    cat >&2 <<EOF
This clone already has a different core.hooksPath:

  $existing_hooks_path

Changing it could disable another repository-local hook setup.
Review that configuration, then rerun with --force if replacing it is intentional:

  ./SetupContributor.sh --force
EOF
    exit 1
fi

echo "Configuring Git LFS filters for this clone..."
git lfs install --local --skip-repo

echo "Configuring shared OpenTournament Git hooks..."
git config --local core.hooksPath .githooks
chmod +x .githooks/pre-push

configured_hooks_path="$(git config --local --get core.hooksPath)"
lfs_url="$(git config --file .lfsconfig --get lfs.url)"
expected_lfs_url="https://git.opentournamentgame.com/opentournament/opentournament.git/info/lfs"

if [[ "$configured_hooks_path" != ".githooks" ]]; then
    echo "Unexpected core.hooksPath value: $configured_hooks_path" >&2
    exit 1
fi

if [[ "$lfs_url" != "$expected_lfs_url" ]]; then
    echo "Unexpected Git LFS endpoint: $lfs_url" >&2
    exit 1
fi

cat <<EOF

OpenTournament contributor setup is complete.

Git repository:
  GitHub forks, branches, and pull requests

Git LFS storage:
  $lfs_url

Public users can download LFS files anonymously.
Pushing new or modified LFS files requires GitLab contributor access.

When Git requests credentials for git.opentournamentgame.com:
  Username: your GitLab username
  Password: your GitLab personal access token

Detailed instructions:
  docs/GIT_LFS.md

Recommended verification:
  git lfs pull
  git lfs status
EOF
