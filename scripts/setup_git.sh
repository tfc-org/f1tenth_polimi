#!/usr/bin/env bash
# One-time git setup for a fresh clone of F1tenth_PoliMI.
# Safe to run more than once. Run from anywhere inside the repo:
#   bash scripts/setup_git.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Our forks and the upstream repos they track, as "path upstream-url".
# (Plain list, not an associative array: macOS still ships bash 3.2.)
FORKS=(
    "ros2_ws/src/f1tenth_system https://github.com/f1tenth/f1tenth_system.git"
)

echo "==> Fetching submodules (and their nested submodules)"
git submodule update --init --recursive

echo "==> Refusing pushes that point at unpushed submodule commits"
git config push.recurseSubmodules check

echo "==> Making pull/switch also update submodules"
git config submodule.recurse true

echo "==> Leaving the private docs/Latex_Templates out of pull/switch (see CONTRIBUTING.md)"
if ! git config submodule.docs/Latex_Templates.active >/dev/null; then
    if [ -e docs/Latex_Templates/.git ]; then
        git config submodule.docs/Latex_Templates.active true
    else
        git config submodule.docs/Latex_Templates.active false
    fi
fi

for entry in "${FORKS[@]}"; do
    read -r path url <<< "$entry"
    echo "==> $path"
    if git -C "$path" remote get-url upstream >/dev/null 2>&1; then
        echo "    upstream already set: $(git -C "$path" remote get-url upstream)"
    else
        git -C "$path" remote add upstream "$url"
        echo "    added upstream: $url"
    fi

    branch=$(git config -f .gitmodules "submodule.$path.branch" || true)
    [ -z "$branch" ] && continue
    # Submodules start in detached HEAD; put them on our branch when it exists on the fork.
    if git -C "$path" rev-parse --verify --quiet "$branch" >/dev/null; then
        git -C "$path" switch "$branch"
    elif git -C "$path" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        git -C "$path" switch -c "$branch" --track "origin/$branch"
    else
        echo "    branch $branch not on origin yet: staying on the pinned commit (detached)"
    fi
done

echo
echo "Done."
